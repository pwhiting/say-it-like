import Foundation

/// How hard the prompts are and how strictly the judge scores.
nonisolated enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, actor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .actor: "Actor"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "Big feelings. Great for kids."
        case .medium: "A bit of everything."
        case .actor: "Subtle shades. Tough judge."
        }
    }

    var symbol: String {
        switch self {
        case .easy: "face.smiling.inverse"
        case .medium: "theatermasks.fill"
        case .actor: "star.circle.fill"
        }
    }

    /// Which prompt tiers this difficulty draws from (same as the web game).
    var tiers: [KeyPath<Tiered, [String]>] {
        switch self {
        case .easy: [\.easy]
        case .medium: [\.easy, \.medium]
        case .actor: [\.medium, \.actor]
        }
    }
}

/// A prompt list split by difficulty tier.
nonisolated struct Tiered: Decodable, Sendable {
    let easy: [String]
    let medium: [String]
    let actor: [String]

    func pool(_ difficulty: Difficulty) -> [String] {
        difficulty.tiers.flatMap { self[keyPath: $0] }
    }
}

/// Everything players perform, plus what the game says when someone wins.
/// Generated from the web game's `public/*.js` by `ios/scripts/export-game-data.mjs`.
nonisolated struct GameData: Decodable, Sendable {
    let moods: Tiered
    let characters: Tiered
    let actions: Tiered
    let situations: Tiered
    let styles: Tiered
    let lines: [String]
    let winPhrases: [String: [String]]
    let topScoreTags: [String]
    let lowScoreTags: [String]

    static let shared: GameData = {
        guard let url = Bundle.main.url(forResource: "GameData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(GameData.self, from: data)
        else { fatalError("GameData.json is missing or invalid. Run ios/scripts/export-game-data.mjs.") }
        return decoded
    }()

    func phrases(_ kind: String) -> [String] {
        winPhrases[kind] ?? ["{n} wins!"]
    }
}
