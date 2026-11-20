import Foundation

nonisolated enum MannerKind: String, Codable, Sendable {
    case mood, action, situation, style

    /// Label shown next to the score bar.
    var label: String {
        switch self {
        case .mood: "Mood"
        case .action: "Action"
        case .situation: "Situation"
        case .style: "Style"
        }
    }

    /// How the judge is told what kind of manner was asked for.
    var judgeLabel: String {
        switch self {
        case .mood: "Mood (a feeling)"
        case .action: "Action (what they are trying to do to the listener)"
        case .situation: "Situation (a physical circumstance that changes the voice)"
        case .style: "Style (a theatrical or broadcast style)"
        }
    }
}

nonisolated struct Manner: Codable, Hashable, Sendable {
    var kind: MannerKind
    var text: String
}

/// One round's line and direction, e.g. "Hello, partner." / "like a scared cowboy".
nonisolated struct Prompt: Codable, Hashable, Sendable {
    var line: String
    var manner: Manner?
    var character: String?
    var direction: String
    var difficulty: Difficulty

    init(line: String, manner: Manner?, character: String?, difficulty: Difficulty) {
        self.line = line
        self.manner = manner
        self.character = character
        self.difficulty = difficulty
        self.direction = Prompt.direction(manner: manner, character: character)
    }

    // Characters who are one specific person take no article: "like Santa Claus".
    private static let named: Set<String> = ["Santa Claus"]

    private static func withArticle(_ words: String) -> String {
        if named.contains(words) { return words }
        let first = words.lowercased().first
        return "\("aeiou".contains(first ?? "x") ? "an" : "a") \(words)"
    }

    /// The direction shown to players, e.g. "like a scared cowboy" or "in slow motion".
    static func direction(manner: Manner?, character: String?) -> String {
        guard let manner else { return "like \(withArticle(character ?? "star"))" }
        switch manner.kind {
        case .style:
            return manner.text
        case .mood:
            if let character { return "like \(withArticle("\(manner.text) \(character)"))" }
            return "like you're \(manner.text)"
        case .action, .situation:
            if let character { return "like \(withArticle(character)) who's \(manner.text)" }
            return "like you're \(manner.text)"
        }
    }

    /// Same mix as the web game: mood + character is the most common, then the others.
    static func random(_ difficulty: Difficulty, data: GameData = .shared) -> Prompt {
        func pick(_ list: Tiered) -> String { list.pool(difficulty).randomElement() ?? "" }
        let r = Double.random(in: 0..<1)
        var manner: Manner?
        var character: String?
        switch r {
        case ..<0.35:
            manner = Manner(kind: .mood, text: pick(data.moods))
            character = pick(data.characters)
        case ..<0.5:
            manner = Manner(kind: .mood, text: pick(data.moods))
        case ..<0.62:
            character = pick(data.characters)
        case ..<0.8:
            manner = Manner(kind: .action, text: pick(data.actions))
            if Bool.random() { character = pick(data.characters) }
        case ..<0.93:
            manner = Manner(kind: .situation, text: pick(data.situations))
            if Double.random(in: 0..<1) < 0.4 { character = pick(data.characters) }
        default:
            manner = Manner(kind: .style, text: pick(data.styles))
        }
        return Prompt(line: data.lines.randomElement() ?? "Hello, partner.",
                      manner: manner, character: character, difficulty: difficulty)
    }
}
