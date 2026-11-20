import AVFoundation
import Observation

/// Every call that can block on the audio system (session setup, starting and stopping players
/// and the recorder) runs on this one serial queue, never on the main thread, so the UI can't
/// hang while the audio hardware wakes up. Being serial keeps calls in the order they were made.
nonisolated enum AudioQueue {
    private static let queue = DispatchQueue(label: "in.dugg.sayitlike.audio", qos: .userInitiated)

    static func async(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }

    /// Runs `work` on the audio queue and waits for its result. The work is queued before the
    /// caller first suspends, so it keeps its place in line with other audio calls.
    static func perform<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { c in
            queue.async { c.resume(with: Result { try work() }) }
        }
    }
}

enum AudioSession {
    /// Play and record through the loudspeaker (not the earpiece), ignoring the silent switch,
    /// so the announcer and fanfare are heard while the phone is passed around.
    static func configure() {
        AudioQueue.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try? session.setActive(true)
        }
    }

    static func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static var microphoneDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }
}

/// Plays sounds on the audio queue. A channel plays one sound at a time (a new one stops the
/// last) unless it `mixes`, in which case sounds overlap.
nonisolated final class AudioChannel: @unchecked Sendable {
    private let mixes: Bool
    private var players: [AVAudioPlayer] = [] // only touched on the audio queue

    init(mixes: Bool = false) {
        self.mixes = mixes
    }

    /// Starts playing in call order with `stop()`. `started` gets the sound's length in
    /// seconds, or 0 if it couldn't be played.
    func start(_ data: Data, volume: Float = 1, started: (@Sendable (TimeInterval) -> Void)? = nil) {
        AudioQueue.async { [self] in
            if mixes { players.removeAll { !$0.isPlaying } } else { stopPlayers() }
            guard let p = try? AVAudioPlayer(data: data) else { started?(0); return }
            p.volume = volume
            p.prepareToPlay()
            p.play()
            players.append(p)
            started?(p.duration)
        }
    }

    /// Starts playing and returns the sound's length once it has started (0 if it couldn't).
    func play(_ data: Data, volume: Float = 1) async -> TimeInterval {
        await withCheckedContinuation { c in
            start(data, volume: volume) { c.resume(returning: $0) }
        }
    }

    func stop() {
        AudioQueue.async { [self] in stopPlayers() }
    }

    private func stopPlayers() {
        players.forEach { $0.stop() }
        players = []
    }
}

/// Records one take to a temporary WAV file, then hands back the bytes and deletes the file,
/// so nothing is left on disk.
@Observable
final class TakeRecorder {
    @ObservationIgnored private let core = Core()

    static let mime = "audio/wav"

    func start() async throws { try await AudioQueue.perform { [core] in try core.start() } }

    /// Stops and returns the recording, or nil if nothing usable was captured.
    func stop() async -> Data? { (try? await AudioQueue.perform { [core] in core.stop() }) ?? nil }

    func cancel() { AudioQueue.async { [core] in core.cancel() } }

    /// 0...1 loudness for the live meter. Cheap enough to call every frame.
    func level() -> Double { core.level() }

    /// The recorder itself. Starting and stopping happen on the audio queue; the meter is read
    /// from the main thread, so the shared state sits behind a lock.
    private nonisolated final class Core: @unchecked Sendable {
        private let lock = NSLock()
        private var recorder: AVAudioRecorder?
        private var url: URL?

        func start() throws {
            cancel()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("take-\(UUID().uuidString).wav")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 24_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            guard r.record() else {
                try? FileManager.default.removeItem(at: url)
                throw OpenAIError(message: "The microphone could not start recording.")
            }
            lock.withLock {
                recorder = r
                self.url = url
            }
        }

        func level() -> Double {
            lock.withLock {
                guard let r = recorder, r.isRecording else { return 0 }
                r.updateMeters()
                let db = Double(r.averagePower(forChannel: 0))
                return max(0, min(1, (db + 48) / 44))
            }
        }

        func stop() -> Data? {
            guard let (r, url) = take() else { return nil }
            let seconds = r.currentTime
            r.stop()
            defer { try? FileManager.default.removeItem(at: url) }
            guard seconds > 0.3 else { return nil }
            return try? Data(contentsOf: url)
        }

        func cancel() {
            guard let (r, url) = take() else { return }
            r.stop()
            try? FileManager.default.removeItem(at: url)
        }

        /// Hands over the current recording and forgets it, so the meter stops reading it.
        private func take() -> (AVAudioRecorder, URL)? {
            lock.withLock {
                defer { recorder = nil; url = nil }
                guard let recorder, let url else { return nil }
                return (recorder, url)
            }
        }
    }
}

/// Plays back takes on the results screen, one at a time.
@Observable
final class TakePlayer {
    private(set) var playingID: UUID?
    @ObservationIgnored private let channel = AudioChannel()
    @ObservationIgnored private var finish: Task<Void, Never>?

    func toggle(id: UUID, audio: Data) {
        if playingID == id { stop(); return }
        stop()
        playingID = id
        channel.start(audio) { [weak self] duration in
            Task { @MainActor in self?.started(id, duration: duration) }
        }
    }

    private func started(_ id: UUID, duration: TimeInterval) {
        guard playingID == id else { return }
        guard duration > 0 else { stop(); return }
        finish = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration + 0.1))
            guard !Task.isCancelled, self?.playingID == id else { return }
            self?.stop()
        }
    }

    func stop() {
        finish?.cancel()
        finish = nil
        channel.stop()
        playingID = nil
    }
}

/// Estimates how long a line takes to say by having the on-device voice render it silently
/// into memory (it is never played). Falls back to a words-per-second estimate.
nonisolated final class SpeechLengthEstimator: @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    func seconds(for text: String) async -> Double? {
        let tally = Tally()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            tally.continuation = cont
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    tally.finish()
                } else {
                    tally.add(Double(pcm.frameLength) / pcm.format.sampleRate)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) { tally.finish() }
        }
    }

    private final class Tally: @unchecked Sendable {
        private let lock = NSLock()
        private var total = 0.0
        private var done = false
        var continuation: CheckedContinuation<Double?, Never>?

        func add(_ s: Double) {
            lock.withLock { total += s }
        }

        func finish() {
            let result: (CheckedContinuation<Double?, Never>?, Double) = lock.withLock {
                guard !done else { return (nil, 0) }
                done = true
                return (continuation, total)
            }
            result.0?.resume(returning: result.1 > 0.2 ? result.1 : nil)
        }
    }
}
