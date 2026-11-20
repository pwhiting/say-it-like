import AVFoundation
import Observation

/// The game-show announcer. Lines are generated with OpenAI's voices: the "Get ready, Pete!"
/// clips are made once the players are known, so there is no wait between turns.
@Observable
final class Announcer {
    enum Cue: Equatable { case none, getReady, lights, camera, action }

    private let settings: AppSettings
    private var clips: [String: Data] = [:] // "voice|text" -> MP3
    private var player: AVAudioPlayer?
    private(set) var readyNames: Set<String> = []
    private(set) var lastError: String?

    nonisolated static let instructions = """
    You are the announcer of a family game show where kids and grown-ups take turns voice \
    acting. Sound like a warm, charismatic host: big energy, a bright smile in your voice, \
    clear diction a young child can follow. Build excitement, but never shout harshly.
    """

    static let cueWords: [(Cue, String)] = [(.lights, "Lights!"), (.camera, "Camera!"), (.action, "Action!")]

    init(settings: AppSettings) {
        self.settings = settings
    }

    static func getReadyText(_ name: String) -> String { "Get ready, \(name)!" }

    private func key(_ text: String) -> String { "\(settings.voice)|\(text)" }

    /// Generates every clip the turns will need. Safe to call again: existing clips are kept.
    func prepare(names: [String]) async {
        lastError = nil
        readyNames = readyNames.filter { clips[key(Self.getReadyText($0))] != nil }
        let texts = names.map(Self.getReadyText) + Self.cueWords.map(\.1)
        let missing = texts.filter { clips[key($0)] == nil }
        let voice = settings.voice, model = settings.effectiveSpeechModel, apiKey = settings.trimmedKey
        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for text in missing {
                group.addTask {
                    do {
                        let data = try await OpenAI.speech(text: text, voice: voice, model: model,
                                                           instructions: Self.delivery(for: text), apiKey: apiKey)
                        return (text, .success(data))
                    } catch {
                        return (text, .failure(error))
                    }
                }
            }
            for await (text, result) in group {
                switch result {
                case .success(let data): clips["\(voice)|\(text)"] = data
                case .failure(let error): lastError = error.localizedDescription
                }
                if let name = names.first(where: { Self.getReadyText($0) == text }), clips["\(voice)|\(text)"] != nil {
                    readyNames.insert(name)
                }
            }
        }
    }

    nonisolated static func delivery(for text: String) -> String {
        switch text {
        case "Lights!": instructions + " Say \"Lights!\" crisply, like flipping on a spotlight."
        case "Camera!": instructions + " Say \"Camera!\" crisply, building anticipation."
        case "Action!": instructions + " Punch \"Action!\" with a big, joyful burst, like a director starting the scene."
        default: instructions + " Call the player up with excitement, like welcoming them to the stage."
        }
    }

    func clip(_ text: String) -> Data? { clips[key(text)] }

    var hasTurnClips: Bool { Self.cueWords.allSatisfy { clip($0.1) != nil } }

    /// Plays MP3 data and returns when it finishes (or is stopped).
    func play(_ data: Data) async {
        stop()
        guard let p = try? AVAudioPlayer(data: data) else { return }
        player = p
        p.prepareToPlay()
        p.play()
        try? await Task.sleep(for: .seconds(p.duration))
    }

    /// Speaks any line, generating it on the fly. Returns false if the voice was unavailable.
    @discardableResult
    func say(_ text: String) async -> Bool {
        guard let data = await generate(text) else { return false }
        await play(data)
        return true
    }

    func generate(_ text: String, instructions: String? = nil) async -> Data? {
        if let cached = clips[key(text)] { return cached }
        guard settings.hasAPIKey else { return nil }
        do {
            let data = try await OpenAI.speech(text: text, voice: settings.voice, model: settings.effectiveSpeechModel,
                                               instructions: instructions ?? Self.instructions, apiKey: settings.trimmedKey)
            clips[key(text)] = data
            return data
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// Forgets every clip (they contain player names).
    func clear() {
        stop()
        clips = [:]
        readyNames = []
    }
}

/// Short sounds synthesized in code (no audio files): fanfares, ticks, a drumroll.
/// Never played while a take is recording.
final class SoundFX {
    private let settings: AppSettings
    private var players: [AVAudioPlayer] = []

    private lazy var smallFanfare = Self.notes([(523.25, 0), (659.25, 0.1), (783.99, 0.2), (1046.5, 0.3)])
    private lazy var bigFanfare = Self.notes([(523.25, 0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36), (783.99, 0.56), (1046.5, 0.68)])
    private lazy var tickSound = Self.notes([(987.77, 0)], lastLength: 0.14, gain: 0.7)
    private lazy var wrapSound = Self.notes([(659.25, 0), (987.77, 0.09)], lastLength: 0.35, gain: 0.8)
    private lazy var drumroll = Self.roll(seconds: 1.7)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func fanfare(big: Bool = false) { play(big ? bigFanfare : smallFanfare) }
    func tick() { play(tickSound) }
    func wrap() { play(wrapSound) }
    func roll() { play(drumroll, volume: 0.55) }

    private func play(_ data: Data, volume: Float = 1) {
        guard settings.soundEffects, let p = try? AVAudioPlayer(data: data) else { return }
        players.removeAll { !$0.isPlaying }
        p.volume = volume
        p.play()
        players.append(p)
    }

    func stopAll() {
        players.forEach { $0.stop() }
        players = []
    }

    // MARK: synthesis

    private static let rate = 44_100.0

    /// Bright brass-like notes: a triangle wave plus a soft octave, with quick attack and decay.
    private static func notes(_ notes: [(Double, Double)], lastLength: Double = 0.7, gain: Float = 1) -> Data {
        let end = (notes.last?.1 ?? 0) + lastLength + 0.1
        var samples = [Float](repeating: 0, count: Int(end * rate))
        for (k, (freq, at)) in notes.enumerated() {
            let length = k == notes.count - 1 ? lastLength : 0.16
            for (shape, vol, mult) in [(0, 0.16, 1.0), (1, 0.05, 2.0)] {
                let f = freq * mult
                let start = Int(at * rate)
                let count = Int((length + 0.05) * rate)
                for n in 0..<count where start + n < samples.count {
                    let t = Double(n) / rate
                    let env: Double = t < 0.02
                        ? 0.0001 * pow(vol / 0.0001, t / 0.02)
                        : vol * pow(0.0001 / vol, min(1, (t - 0.02) / (length - 0.02)))
                    let phase = t * f
                    let wave = shape == 0
                        ? 2 * abs(2 * (phase - (phase + 0.5).rounded(.down))) - 1
                        : sin(2 * .pi * phase)
                    samples[start + n] += Float(wave * env)
                }
            }
        }
        return wav(samples.map { $0 * gain * 2.2 })
    }

    /// A soft snare roll that swells, for "And the round goes to…".
    private static func roll(seconds: Double) -> Data {
        let count = Int(seconds * rate)
        var samples = [Float](repeating: 0, count: count)
        var seed: UInt32 = 12345
        var low: Float = 0
        for n in 0..<count {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Float(Int32(bitPattern: seed)) / Float(Int32.max)
            low += 0.35 * (noise - low)
            let t = Double(n) / rate
            let stroke = 1 - (t * 22).truncatingRemainder(dividingBy: 1) // 22 strokes per second
            let swell = 0.25 + 0.75 * (t / seconds)
            let fade = min(1, (seconds - t) / 0.08)
            samples[n] = low * Float(pow(stroke, 3) * swell * fade) * 0.9
        }
        return wav(samples)
    }

    private static func wav(_ samples: [Float]) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * Float(Int16.max))
            withUnsafeBytes(of: v.littleEndian) { pcm.append(contentsOf: $0) }
        }
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
        d.append(pcm)
        return d
    }
}
