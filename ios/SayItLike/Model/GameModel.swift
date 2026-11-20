import SwiftUI
import Observation

struct Player: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var colorIndex: Int
    var score = 0
    var wins = 0
    var lastWin = 0

    var color: Color { Theme.playerColors[colorIndex % Theme.playerColors.count] }
    var initial: String { name.first.map { String($0).uppercased() } ?? "?" }
}

/// One player's recording this round. Audio lives in memory only, and only until the round's
/// results have been shown.
struct Take: Identifiable {
    let id = UUID()
    var audio: Data
    var prompt: Prompt
    var result: JudgeResult?
    var error: String?

    var settled: Bool { result != nil || error != nil }
}

struct Outcome {
    enum Kind: String { case blowout, clear, solid, close, tie, none }
    var winners: [Int]
    var text: String
    var kind: Kind
}

struct Standing: Identifiable {
    var id: Int { index }
    let index: Int
    let name: String
    let score: Int
    let wins: Int
    let lastWin: Int
}

@Observable
final class GameModel {
    enum Phase: Equatable { case setup, preparing, round, results, final }
    enum Stage: Equatable { case ready, announcing, recording(start: Date, seconds: Double), review }
    enum Reveal { case hidden, suspense, shown }

    static let maxPlayers = 12

    let settings: AppSettings
    let announcer: Announcer
    let sfx: SoundFX
    let recorder = TakeRecorder()
    let takePlayer = TakePlayer()
    private let estimator = SpeechLengthEstimator()

    var phase: Phase = .setup
    var players: [Player] = []
    var totalRounds = 5
    var difficulty: Difficulty = .medium
    var round = 0
    var prompt = Prompt(line: "Hello, partner.", manner: nil, character: "cowboy", difficulty: .medium)
    var order: [Int] = []
    var turn = 0
    var takes: [Int: Take] = [:]
    var stage: Stage = .ready
    var cue: Announcer.Cue = .none
    var recordSeconds: Double = 8
    var outcome: Outcome?
    var reveal: Reveal = .hidden
    var confettiBurst = 0
    var confettiPower = 1.0
    var alert: String?
    var showSettings = false

    private var tallied = false
    private var celebratedKey = ""
    private var turnTask: Task<Void, Never>?
    private var autoStop: Task<Void, Never>?
    private var stopping = false
    private var timerTask: Task<Void, Never>?
    private var revealTask: Task<Void, Never>?
    private var winnerSpeech: Task<Data?, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        self.announcer = Announcer(settings: settings)
        self.sfx = SoundFX(settings: settings)
    }

    // MARK: - Setup

    /// Trims names, drops blanks, and numbers duplicates ("Sam", "Sam 2").
    static func cleanNames(_ raw: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxPlayers)
            .map { name in
                let n = (seen[name.lowercased()] ?? 0) + 1
                seen[name.lowercased()] = n
                return n > 1 ? "\(name) \(n)" : name
            }
    }

    func startGame(names: [String], rounds: Int, difficulty: Difficulty) async {
        players = names.enumerated().map { Player(name: $1, colorIndex: $0) }
        totalRounds = max(1, min(20, rounds))
        self.difficulty = difficulty
        round = 0
        alert = nil

        guard await AudioSession.requestMicrophone() else {
            alert = "Say It Like needs the microphone to hear each performance. Turn it on in Settings → Privacy & Security → Microphone."
            return
        }
        AudioSession.configure()
        withAnimation { phase = .preparing }

        let started = Date()
        if settings.announcerOn {
            await announcer.prepare(names: players.map(\.name))
        }
        // Give the "setting the stage" moment a beat, even when everything was cached.
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 1.4 { try? await Task.sleep(for: .seconds(1.4 - elapsed)) }
        guard phase == .preparing else { return }
        startRound()
    }

    func playAgain() {
        players = players.map { Player(name: $0.name, colorIndex: $0.colorIndex) }
        round = 0
        Task { await startGame(names: players.map(\.name), rounds: totalRounds, difficulty: difficulty) }
    }

    func endGame() {
        turnTask?.cancel()
        autoStop?.cancel()
        revealTask?.cancel()
        winnerSpeech?.cancel()
        recorder.cancel()
        takePlayer.stop()
        announcer.clear()
        sfx.stopAll()
        takes = [:]
        outcome = nil
        stage = .ready
        cue = .none
        withAnimation { phase = .setup }
    }

    // MARK: - Turn order

    /// Round 1 goes in the order the names were entered. After that, most round wins goes
    /// first; among players tied on wins, the one who won most recently goes first. Anyone
    /// still tied keeps the original order.
    static func turnOrder(_ stats: [(wins: Int, lastWin: Int)]) -> [Int] {
        stats.indices.sorted { a, b in
            if stats[a].wins != stats[b].wins { return stats[a].wins > stats[b].wins }
            if stats[a].lastWin != stats[b].lastWin { return stats[a].lastWin > stats[b].lastWin }
            return a < b
        }
    }

    // MARK: - Round

    func startRound() {
        takePlayer.stop()
        round += 1
        prompt = Prompt.random(difficulty)
        order = Self.turnOrder(players.map { ($0.wins, $0.lastWin) })
        turn = 0
        takes = [:] // last round's recordings are released here
        outcome = nil
        reveal = .hidden
        tallied = false
        celebratedKey = ""
        stage = .ready
        cue = .none
        updateTimer()
        withAnimation(.smooth(duration: 0.5)) { phase = .round }
    }

    var currentPlayer: Int { order.indices.contains(turn) ? order[turn] : 0 }
    var nextPlayer: Int? { order.indices.contains(turn + 1) ? order[turn + 1] : nil }
    var canChangePrompt: Bool { turn == 0 && stage == .ready }

    func newPrompt() {
        guard canChangePrompt else { return }
        withAnimation(.spring(duration: 0.45)) { prompt = Prompt.random(difficulty) }
        updateTimer()
    }

    func useCustomPrompt(line: String, mood: String, character: String) {
        let manner = mood.isEmpty ? nil : Manner(kind: .mood, text: mood)
        withAnimation(.spring(duration: 0.45)) {
            prompt = Prompt(line: line, manner: manner, character: character.isEmpty ? nil : character, difficulty: difficulty)
        }
        updateTimer()
    }

    /// The countdown is about 1.3× (by default) how long the on-device voice takes to say the
    /// line, plus a moment to start talking. Directions that slow speech down get extra time.
    private func updateTimer() {
        let p = prompt
        recordSeconds = timerSeconds(spoken: nil, for: p)
        timerTask?.cancel()
        timerTask = Task {
            let spoken = await estimator.seconds(for: p.line)
            guard !Task.isCancelled, p == prompt, let spoken else { return }
            recordSeconds = timerSeconds(spoken: spoken, for: p)
        }
    }

    private func timerSeconds(spoken: Double?, for p: Prompt) -> Double {
        let words = p.line.split(whereSeparator: \.isWhitespace).count
        var t = (spoken ?? Double(words) / 2.6 + 0.4) * settings.pace.multiplier
        let d = p.direction.lowercased()
        if d.contains("slow motion") {
            t *= 1.8
        } else if ["opera", "shakespearean", "melodrama", "poetry", "trailer", "out of breath", "yawning",
                   "trying not to", "sleepy", "drowsy", "exhausted", "sleep", "nursery rhyme"].contains(where: d.contains) {
            t *= 1.25
        }
        if p.difficulty == .easy { t += 1 }
        t += 1 // time to take a breath after "Action!"
        return min(20, max(5, t.rounded(.up)))
    }

    /// "Get ready, Pete!" … "Lights!" … "Camera!" … "Action!", then recording starts.
    func beginTurn() {
        guard stage == .ready, phase == .round else { return }
        Haptics.tap()
        let name = players[currentPlayer].name
        withAnimation(.snappy) { stage = .announcing; cue = .getReady }
        turnTask = Task {
            let voiced = settings.announcerOn && announcer.hasTurnClips
            if voiced {
                var ready = announcer.clip(Announcer.getReadyText(name))
                if ready == nil { ready = await announcer.generate(Announcer.getReadyText(name), instructions: Announcer.delivery(for: "")) }
                if let ready { await announcer.play(ready) } else { try? await Task.sleep(for: .seconds(1.1)) }
            } else {
                try? await Task.sleep(for: .seconds(1.3))
            }
            for (cue, word) in Announcer.cueWords {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.3)) { self.cue = cue }
                if cue == .action { Haptics.action() } else { Haptics.tick() }
                if voiced, let clip = announcer.clip(word) {
                    await announcer.play(clip)
                } else {
                    if cue != .action { sfx.tick() }
                    try? await Task.sleep(for: .seconds(cue == .action ? 0.45 : 0.7))
                }
            }
            guard !Task.isCancelled, stage == .announcing else { return }
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            try await recorder.start()
        } catch {
            alert = error.localizedDescription
            withAnimation { stage = .ready; cue = .none }
            return
        }
        // The turn may have been interrupted while the microphone was starting.
        guard !Task.isCancelled, stage == .announcing else { recorder.cancel(); return }
        let seconds = recordSeconds
        withAnimation(.snappy) { stage = .recording(start: .now, seconds: seconds) }
        autoStop = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            finishRecording()
        }
    }

    func finishRecording() {
        guard case .recording = stage, !stopping else { return }
        stopping = true
        autoStop?.cancel()
        Task {
            let audio = await recorder.stop()
            stopping = false
            // If the turn was interrupted meanwhile, the take is discarded.
            guard case .recording = stage else { return }
            keep(audio)
        }
    }

    private func keep(_ audio: Data?) {
        cue = .none
        guard let audio else {
            alert = "Nothing was recorded. Give it another go!"
            withAnimation { stage = .ready }
            return
        }
        let index = currentPlayer
        takes[index] = Take(audio: audio, prompt: prompt)
        judge(index)
        Haptics.success()
        sfx.wrap()
        withAnimation(.spring(duration: 0.5)) { stage = .review }
    }

    /// Hands the phone to the next player, or goes to the results after the last one.
    func passPhone() {
        takePlayer.stop()
        guard stage == .review else { return }
        if turn + 1 < order.count {
            withAnimation(.smooth(duration: 0.45)) {
                turn += 1
                stage = .ready
            }
        } else {
            showResults()
        }
    }

    /// Stops a turn in progress if the app leaves the foreground. The take is discarded.
    func interrupt() {
        switch stage {
        case .announcing:
            turnTask?.cancel()
            announcer.stop()
            withAnimation { stage = .ready; cue = .none }
        case .recording:
            autoStop?.cancel()
            recorder.cancel()
            withAnimation { stage = .ready; cue = .none }
        default:
            break
        }
        takePlayer.stop()
    }

    // MARK: - Judging (runs in the background while the next player performs)

    func judge(_ index: Int) {
        guard let take = takes[index] else { return }
        takes[index]?.result = nil
        takes[index]?.error = nil
        let id = take.id
        let key = settings.trimmedKey, model = settings.effectiveJudgeModel
        Task {
            do {
                let result = try await Judge.score(audio: take.audio, mime: TakeRecorder.mime, prompt: take.prompt,
                                                   apiKey: key, model: model)
                guard takes[index]?.id == id else { return }
                takes[index]?.result = result
            } catch {
                guard takes[index]?.id == id else { return }
                takes[index]?.error = error.localizedDescription
            }
            judgingChanged()
        }
    }

    func retryJudging(_ index: Int) {
        outcome = nil
        judge(index)
    }

    private func judgingChanged() {
        if phase == .results { evaluateReveal() }
    }

    var allSettled: Bool { !order.isEmpty && order.allSatisfy { takes[$0]?.settled ?? false } }
    var isRevealed: Bool { reveal == .shown && allSettled }

    // MARK: - Results

    private func showResults() {
        reveal = .hidden
        outcome = nil
        withAnimation(.smooth(duration: 0.5)) { phase = .results }
        evaluateReveal()
    }

    private func evaluateReveal() {
        guard allSettled else { return }
        if outcome == nil { outcome = decideRound() }
        switch reveal {
        case .hidden:
            withAnimation { reveal = .suspense }
            prepareWinnerSpeech()
            sfx.roll()
            revealTask = Task {
                try? await Task.sleep(for: .seconds(UIAccessibility.isReduceMotionEnabled ? 0.6 : 1.8))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.6)) { reveal = .shown }
                celebrate()
            }
        case .shown:
            celebrate() // a retried take may have changed the winner
        case .suspense:
            break
        }
    }

    private func prepareWinnerSpeech() {
        winnerSpeech?.cancel()
        guard settings.announcerOn, let outcome, !outcome.winners.isEmpty else { winnerSpeech = nil; return }
        let text = Self.speakable(outcome.text)
        winnerSpeech = Task { await announcer.generate(text) }
    }

    private func celebrate() {
        guard let outcome, !outcome.winners.isEmpty else { return }
        let key = outcome.winners.map(String.init).joined(separator: ",")
        guard key != celebratedKey else { return }
        celebratedKey = key
        confettiPower = outcome.kind == .blowout ? 1.3 : 1
        confettiBurst += 1
        sfx.fanfare()
        Haptics.success()
        let speech = winnerSpeech
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            if let data = await speech?.value, phase == .results { await announcer.play(data) }
        }
    }

    /// Decides who won the round and the phrase for the winning card. Ties share the win.
    func decideRound() -> Outcome {
        let data = GameData.shared
        let scored = players.indices
            .compactMap { i in takes[i]?.result.map { (i: i, name: players[i].name, total: $0.total) } }
            .sorted { $0.total > $1.total }
        guard let top = scored.first?.total else { return Outcome(winners: [], text: "", kind: .none) }

        if players.count == 1 {
            let band = top >= 85 ? "soloGreat" : top >= 60 ? "soloGood" : top >= 35 ? "soloOk" : "soloLow"
            return Outcome(winners: top >= 60 ? [0] : [], text: data.phrases(band).randomElement() ?? "",
                           kind: top >= 85 ? .blowout : .solid)
        }

        let leaders = scored.filter { $0.total == top }
        let runnerUp = leaders.count < scored.count ? scored[leaders.count].total : 0
        let margin = top - runnerUp
        let kind: Outcome.Kind = leaders.count > 1 ? .tie
            : margin >= 25 ? .blowout : margin >= 12 ? .clear : margin >= 4 ? .solid : .close
        var text = (data.phrases(kind.rawValue).randomElement() ?? "{n} wins!")
            .replacingOccurrences(of: "{n}", with: Self.joinNames(leaders.map(\.name)))
        if top >= 90, let tag = data.topScoreTags.randomElement() { text += " \(tag)" }
        else if top < 30, let tag = data.lowScoreTags.randomElement() { text += " \(tag)" }
        return Outcome(winners: leaders.map(\.i), text: text, kind: kind)
    }

    static func joinNames(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    /// Text for the announcer: no emoji or stage directions in parentheses.
    static func speakable(_ text: String) -> String {
        let noEmoji = String(String.UnicodeScalarView(text.unicodeScalars.filter {
            !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x2000) || $0.value == 0xFE0F || $0.value == 0x00D7)
        }))
        return noEmoji.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Each player's totals, including this round once it is revealed but not yet tallied.
    func projected(includeRound: Bool = true) -> [Standing] {
        let pending = includeRound && !tallied && outcome != nil && isRevealed
        return players.enumerated().map { i, p in
            let won = pending && players.count > 1 && (outcome?.winners.contains(i) ?? false)
            return Standing(index: i, name: p.name,
                            score: p.score + (pending ? takes[i]?.result?.total ?? 0 : 0),
                            wins: p.wins + (won ? 1 : 0),
                            lastWin: won ? round : p.lastWin)
        }
    }

    /// Ranked by total score, then wins.
    func standings(includeRound: Bool = true) -> [Standing] {
        projected(includeRound: includeRound).sorted { $0.score != $1.score ? $0.score > $1.score : $0.wins > $1.wins }
    }

    var nextRoundOrder: [Int] {
        Self.turnOrder(projected().map { ($0.wins, $0.lastWin) })
    }

    var isLastRound: Bool { round >= totalRounds }

    func nextRound() {
        guard isRevealed else { return }
        announcer.stop()
        takePlayer.stop()
        if !tallied {
            for i in players.indices {
                players[i].score += takes[i]?.result?.total ?? 0
                if players.count > 1, outcome?.winners.contains(i) == true {
                    players[i].wins += 1
                    players[i].lastWin = round
                }
            }
            tallied = true
        }
        if isLastRound { showFinal() } else { startRound() }
    }

    // MARK: - Final

    var champions: [Standing] {
        let ranked = standings(includeRound: false)
        return ranked.filter { $0.score == ranked.first?.score }
    }

    private func showFinal() {
        takes = [:] // release the last round's recordings
        withAnimation(.smooth(duration: 0.6)) { phase = .final }
        confettiPower = 1.6
        confettiBurst += 1
        sfx.fanfare(big: true)
        Haptics.success()
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            confettiPower = 1
            confettiBurst += 1
        }
        guard settings.announcerOn else { return }
        let text: String
        if players.count == 1 {
            text = "\(champions.first?.score ?? 0) points! What a performance!"
        } else if champions.count > 1 {
            text = "It's a tie at the top! \(Self.joinNames(champions.map(\.name))) share the crown!"
        } else {
            text = "Ladies and gentlemen, your champion... \(champions.first?.name ?? "")!"
        }
        Task {
            guard let data = await announcer.generate(text) else { return }
            try? await Task.sleep(for: .seconds(0.4))
            if phase == .final { await announcer.play(data) }
        }
    }
}
