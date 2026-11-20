import AVFoundation
import Observation

enum AudioSession {
    /// Play and record through the loudspeaker (not the earpiece), ignoring the silent switch,
    /// so the announcer and fanfare are heard while the phone is passed around.
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setActive(true)
    }

    static func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static var microphoneDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }
}

/// Records one take to a temporary WAV file, then hands back the bytes and deletes the file,
/// so nothing is left on disk.
@Observable
final class TakeRecorder {
    private var recorder: AVAudioRecorder?
    private var url: URL?

    static let mime = "audio/wav"

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
        recorder = r
        self.url = url
    }

    /// 0...1 loudness for the live meter.
    func level() -> Double {
        guard let r = recorder, r.isRecording else { return 0 }
        r.updateMeters()
        let db = Double(r.averagePower(forChannel: 0))
        return max(0, min(1, (db + 48) / 44))
    }

    var isRecording: Bool { recorder?.isRecording ?? false }

    /// Stops and returns the recording, or nil if nothing usable was captured.
    func stop() -> Data? {
        guard let r = recorder, let url else { return nil }
        let seconds = r.currentTime
        r.stop()
        defer { cleanUp() }
        guard seconds > 0.3 else { return nil }
        return try? Data(contentsOf: url)
    }

    func cancel() {
        recorder?.stop()
        cleanUp()
    }

    private func cleanUp() {
        if let url { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        url = nil
    }
}

/// Plays back takes on the results screen, one at a time.
@Observable
final class TakePlayer {
    private(set) var playingID: UUID?
    private var player: AVAudioPlayer?
    private var finish: Task<Void, Never>?

    func toggle(id: UUID, audio: Data) {
        if playingID == id { stop(); return }
        stop()
        guard let p = try? AVAudioPlayer(data: audio) else { return }
        p.volume = 1
        p.play()
        player = p
        playingID = id
        let duration = p.duration
        finish = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration + 0.1))
            guard !Task.isCancelled, self?.playingID == id else { return }
            self?.stop()
        }
    }

    func stop() {
        finish?.cancel()
        player?.stop()
        player = nil
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
