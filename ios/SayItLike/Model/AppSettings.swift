import Foundation
import Observation
import Security

/// How much breathing room the recording countdown gives, relative to how long the line
/// takes to say at a normal pace.
enum TimerPace: String, CaseIterable, Identifiable {
    case snug, standard, relaxed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snug: "Snug"
        case .standard: "Standard"
        case .relaxed: "Relaxed"
        }
    }

    var multiplier: Double {
        switch self {
        case .snug: 1.15
        case .standard: 1.3
        case .relaxed: 1.6
        }
    }

    var detail: String {
        switch self {
        case .snug: "Just enough time. Keeps the game moving."
        case .standard: "About 1.3× as long as the line takes to say."
        case .relaxed: "Extra time for young readers and big pauses."
        }
    }
}

struct AnnouncerVoice: Identifiable, Hashable {
    let id: String
    let blurb: String
    var name: String { id.prefix(1).uppercased() + id.dropFirst() }

    static let all: [AnnouncerVoice] = [
        .init(id: "ash", blurb: "Bright and upbeat"),
        .init(id: "coral", blurb: "Warm and lively"),
        .init(id: "verse", blurb: "Dramatic and theatrical"),
        .init(id: "ballad", blurb: "Smooth storyteller"),
        .init(id: "onyx", blurb: "Deep and booming"),
        .init(id: "nova", blurb: "Crisp and energetic"),
        .init(id: "fable", blurb: "Expressive narrator"),
        .init(id: "shimmer", blurb: "Light and sparkly"),
        .init(id: "sage", blurb: "Calm and friendly"),
        .init(id: "echo", blurb: "Clear and steady"),
        .init(id: "alloy", blurb: "Balanced and neutral"),
        .init(id: "marin", blurb: "Natural and warm"),
        .init(id: "cedar", blurb: "Rich and grounded"),
    ]
}

/// User preferences. Everything except the API key is in UserDefaults; the key is in the
/// Keychain, readable only on this device.
@Observable
final class AppSettings {
    static let defaultSpeechModel = "gpt-4o-mini-tts"

    private let defaults = UserDefaults.standard

    var apiKey: String { didSet { Keychain.save(apiKey) } }
    var announcerOn: Bool { didSet { defaults.set(announcerOn, forKey: "announcerOn") } }
    var voice: String { didSet { defaults.set(voice, forKey: "voice") } }
    var pace: TimerPace { didSet { defaults.set(pace.rawValue, forKey: "pace") } }
    var soundEffects: Bool { didSet { defaults.set(soundEffects, forKey: "soundEffects") } }
    var judgeModel: String { didSet { defaults.set(judgeModel, forKey: "judgeModel") } }
    var speechModel: String { didSet { defaults.set(speechModel, forKey: "speechModel") } }
    var savedNames: [String] { didSet { defaults.set(savedNames, forKey: "names") } }
    var rounds: Int { didSet { defaults.set(rounds, forKey: "rounds") } }
    var difficulty: Difficulty { didSet { defaults.set(difficulty.rawValue, forKey: "difficulty") } }

    var hasAPIKey: Bool { !trimmedKey.isEmpty }
    var trimmedKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    var effectiveJudgeModel: String {
        let m = judgeModel.trimmingCharacters(in: .whitespaces)
        return m.isEmpty ? Judge.defaultModel : m
    }
    var effectiveSpeechModel: String {
        let m = speechModel.trimmingCharacters(in: .whitespaces)
        return m.isEmpty ? Self.defaultSpeechModel : m
    }

    init() {
        let d = UserDefaults.standard
        apiKey = Keychain.load() ?? ""
        announcerOn = d.object(forKey: "announcerOn") as? Bool ?? true
        voice = d.string(forKey: "voice") ?? "ash"
        pace = TimerPace(rawValue: d.string(forKey: "pace") ?? "") ?? .standard
        soundEffects = d.object(forKey: "soundEffects") as? Bool ?? true
        judgeModel = d.string(forKey: "judgeModel") ?? Judge.defaultModel
        speechModel = d.string(forKey: "speechModel") ?? Self.defaultSpeechModel
        savedNames = d.stringArray(forKey: "names") ?? []
        rounds = d.object(forKey: "rounds") as? Int ?? 5
        difficulty = Difficulty(rawValue: d.string(forKey: "difficulty") ?? "") ?? .medium
    }
}

/// Stores the OpenAI key as a generic password, never synced off the device.
enum Keychain {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "SayItLike.OpenAI",
        kSecAttrAccount as String: "apiKey",
    ]

    static func load() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        SecItemDelete(base as CFDictionary)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = base
        item[kSecValueData as String] = Data(trimmed.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
