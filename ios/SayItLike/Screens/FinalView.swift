import SwiftUI

struct FinalView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge
    @State private var appeared = false

    var body: some View {
        let ranked = game.standings(includeRound: false)
        let champs = game.champions
        let multi = game.players.count > 1
        ScrollView {
            VStack(spacing: isLarge ? 28 : 20) {
                VStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: isLarge ? 92 : 72))
                        .foregroundStyle(Theme.goldFill)
                        .shadow(color: Theme.amber.opacity(0.8), radius: 30)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .rotationEffect(.degrees(appeared ? 0 : -25))
                    Eyebrow(text: "Final scores", color: Theme.subtext, size: isLarge ? 16 : 13)
                    Text(headline(champs: champs, multi: multi))
                        .font(.display(isLarge ? 52 : 38, .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text(subline(ranked: ranked, multi: multi))
                        .font(.system(size: isLarge ? 21 : 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, isLarge ? 40 : 24)

                if multi {
                    Podium(ranked: Array(ranked.prefix(3)))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 40)
                }

                Scoreboard(final: true)
            }
            .padding(.horizontal, isLarge ? 40 : 18)
            .padding(.bottom, 24)
            .frame(maxWidth: isLarge ? 820 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            BottomBar(maxWidth: isLarge ? 620 : .infinity) {
                HStack(spacing: 12) {
                    Button {
                        game.endGame()
                    } label: {
                        Text("New game").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass(size: isLarge ? 22 : 19))
                    .frame(maxWidth: 170)
                    Button {
                        Haptics.tap()
                        game.playAgain()
                    } label: {
                        Label("Play again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.primary(size: isLarge ? 24 : 20))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.45).delay(0.15)) { appeared = true }
        }
    }

    private func headline(champs: [Standing], multi: Bool) -> String {
        if !multi { return "\(champs.first?.score ?? 0) points!" }
        if champs.count > 1 { return "\(GameModel.joinNames(champs.map(\.name))) share the crown!" }
        return "\(champs.first?.name ?? "") is the champion!"
    }

    private func subline(ranked: [Standing], multi: Bool) -> String {
        if !multi { return "across \(game.totalRounds) round\(game.totalRounds == 1 ? "" : "s")" }
        var s = "\(ranked.first?.score ?? 0) points"
        let most = game.players.map(\.wins).max() ?? 0
        if most > 0 {
            let names = game.players.filter { $0.wins == most }.map(\.name)
            s += " · Most round wins: \(GameModel.joinNames(names)) (\(most))"
        }
        return s
    }
}

private struct Podium: View {
    let ranked: [Standing]
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        // Second, first, third, like a real podium.
        let slots: [(Standing, Int)] = [1, 0, 2].compactMap { k in ranked.indices.contains(k) ? (ranked[k], k) : nil }
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(slots, id: \.0.id) { s, k in
                let rank = (ranked.firstIndex(where: { $0.score == s.score }) ?? k) + 1
                VStack(spacing: 8) {
                    Avatar(player: game.players[s.index], size: (isLarge ? 74 : 58) * (k == 0 ? 1.2 : 1))
                    Text(s.name)
                        .font(.display(isLarge ? 21 : 17, .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    VStack(spacing: 2) {
                        Text("\(rank)")
                            .font(.display(isLarge ? 40 : 32, .black))
                        Text("\(s.score) pts")
                            .font(.display(isLarge ? 16 : 13, .bold))
                            .opacity(0.8)
                    }
                    .foregroundStyle(k == 0 ? Theme.night : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: (isLarge ? 170 : 128) * [1.0, 0.74, 0.56][k])
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18, style: .continuous)
                            .fill(k == 0 ? AnyShapeStyle(Theme.goldFill)
                                  : AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.08)],
                                                                 startPoint: .top, endPoint: .bottom)))
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }
}
