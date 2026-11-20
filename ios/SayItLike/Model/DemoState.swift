#if DEBUG
import Foundation

/// Debug builds only: jump straight to a screen with sample data, for checking layouts
/// without a microphone or an API key. Launch with `-demo <screen>`, where screen is one of
/// preparing, ready, announcing, recording, review, judging, results, final.
extension GameModel {
    func loadDemoIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return }
        let screen = args[i + 1]

        players = ["Grandpa", "Ava", "Leo", "Mom"].enumerated().map { Player(name: $1, colorIndex: $0) }
        players[1].wins = 2; players[1].score = 168; players[1].lastWin = 2
        players[0].wins = 1; players[0].score = 151; players[0].lastWin = 1
        players[2].score = 122
        players[3].score = 140
        totalRounds = 5
        round = 3
        difficulty = .medium
        prompt = Prompt(line: "I sure do hope the weather doesn't get worse.",
                        manner: Manner(kind: .mood, text: "scared"), character: "cowboy", difficulty: .medium)
        order = Self.turnOrder(players.map { ($0.wins, $0.lastWin) })
        turn = 1
        recordSeconds = 8

        let sample: [(Int, Int?, Int, Int, String, String, String)] = [
            (9, 8, 10, 9, "a cowboy hiding from a tornado", "That shaky drawl and the gulp before “worse” were pure gold!", "Try a tiny pause before the last word."),
            (6, 5, 9, 6, "a nervous rancher at a picnic", "Nice wobble in your voice — the fear came through in the middle.", "Let the cowboy drawl stretch out more."),
            (8, 7, 10, 8, "a sheriff spotting dark clouds", "Great slow build — you sounded like the storm was right behind you!", "Add a big shaky breath at the start."),
            (4, 5, 8, 4, "a calm cowboy on a sunny day", "A clear, friendly reading with a hint of cowboy.", "Let us hear the fear: shake, whisper, gulp!"),
        ]
        func fill(_ count: Int) {
            for (k, idx) in order.prefix(count).enumerated() {
                let s = sample[k % sample.count]
                let total = Judge.total(line: s.2, manner: s.0, character: s.1, flair: s.3)
                takes[idx] = Take(audio: Data(), prompt: prompt,
                                  result: JudgeResult(line: s.2, manner: s.0, character: s.1, flair: s.3, total: total,
                                                      heard: prompt.line, soundedLike: s.4, comment: s.5, tip: s.6))
            }
        }

        switch screen {
        case "preparing":
            phase = .preparing
        case "ready":
            phase = .round; stage = .ready
        case "announcing":
            phase = .round; stage = .announcing; cue = .camera
        case "recording":
            phase = .round; stage = .recording(start: .now.addingTimeInterval(-2.5), seconds: 8)
        case "review":
            fill(2); phase = .round; stage = .review
        case "judging":
            fill(2); turn = order.count - 1; phase = .results
        case "results":
            fill(order.count); turn = order.count - 1
            outcome = decideRound(); reveal = .shown; phase = .results
        case "final":
            round = 5; phase = .final
        default:
            break
        }
        if args.contains("-autoturn") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                beginTurn()
            }
        }
    }
}
#endif
