import SwiftUI

struct ResultsView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    private var cardOrder: [Int] {
        guard game.isRevealed else { return game.order }
        return game.order.sorted { (game.takes[$0]?.result?.total ?? -1) > (game.takes[$1]?.result?.total ?? -1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isLarge ? 22 : 16) {
                Eyebrow(text: "Round \(game.round) of \(game.totalRounds) · Results", color: Theme.subtext, size: isLarge ? 16 : 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                if game.isRevealed {
                    ForEach(Array(cardOrder.enumerated()), id: \.element) { pos, i in
                        ResultCard(index: i, position: pos)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                    Scoreboard(final: false)
                        .transition(.opacity)
                    if game.players.count > 1 && !game.isLastRound {
                        nextOrder
                    }
                } else if game.reveal == .suspense && game.allSettled {
                    Suspense()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    Deliberating()
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, isLarge ? 40 : 18)
            .padding(.bottom, 24)
            .frame(maxWidth: isLarge ? 820 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            BottomBar(maxWidth: isLarge ? 560 : .infinity) {
                Button {
                    Haptics.tap()
                    game.nextRound()
                } label: {
                    Label(game.isLastRound ? "Final scores" : "Next round",
                          systemImage: game.isLastRound ? "crown.fill" : "arrow.right")
                }
                .buttonStyle(game.isLastRound ? PrimaryButtonStyle(fill: AnyShapeStyle(Theme.goldFill), size: isLarge ? 26 : 22)
                                              : PrimaryButtonStyle(size: isLarge ? 26 : 22))
                .disabled(!game.isRevealed)
            }
        }
    }

    private var nextOrder: some View {
        let names = game.nextRoundOrder.map { game.players[$0].name }
        return (Text("Next round: ").foregroundStyle(Theme.faint) + Text(names.joined(separator: " → ")).foregroundStyle(Theme.subtext))
            .font(.system(size: isLarge ? 18 : 15, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// Shown while takes are still being judged.
private struct Deliberating: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "ear.and.waveform")
                .font(.system(size: isLarge ? 64 : 52, weight: .semibold))
                .foregroundStyle(Theme.goldFill)
                .symbolEffect(.pulse)
                .padding(.top, 30)
            Text("The judge is deliberating…")
                .font(.display(isLarge ? 36 : 28, .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Scores are revealed when everyone has been judged.")
                .font(.system(size: isLarge ? 19 : 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.subtext)
                .multilineTextAlignment(.center)
            Card {
                VStack(spacing: 14) {
                    ForEach(game.order, id: \.self) { i in
                        row(i)
                    }
                }
            }
        }
    }

    private func row(_ i: Int) -> some View {
        let take = game.takes[i]
        return HStack(spacing: 12) {
            Avatar(player: game.players[i], size: 38)
            Text(game.players[i].name)
                .font(.display(isLarge ? 22 : 19, .bold))
                .foregroundStyle(.white)
            Spacer()
            if let error = take?.error {
                Button("Retry") { game.retryJudging(i) }
                    .buttonStyle(.glass(size: 15))
                    .accessibilityHint(error)
            } else if take?.result != nil {
                Label("Judged", systemImage: "checkmark.circle.fill")
                    .font(.display(16, .bold))
                    .foregroundStyle(Theme.mint)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(Theme.subtext)
                    Text("Listening").font(.display(16, .semibold)).foregroundStyle(Theme.subtext)
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let error = take?.error {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.coral)
                    .lineLimit(2)
                    .offset(y: 22)
                    .padding(.leading, 50)
            }
        }
        .padding(.bottom, take?.error != nil ? 18 : 0)
    }
}

/// "And the round goes to…" drumroll beat before the reveal.
private struct Suspense: View {
    @Environment(\.isLarge) private var isLarge
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trophy.fill")
                .font(.system(size: isLarge ? 96 : 76))
                .foregroundStyle(Theme.goldFill)
                .shadow(color: Theme.amber.opacity(0.7), radius: 30)
                .phaseAnimator([0.94, 1.06]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.35) }
            Text("And the round goes to…")
                .font(.display(isLarge ? 42 : 32, .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }
}

private struct ResultCard: View {
    let index: Int
    let position: Int
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge
    @State private var shownTotal = 0

    var body: some View {
        let player = game.players[index]
        let take = game.takes[index]
        let won = game.outcome?.winners.contains(index) ?? false
        let solo = game.players.count == 1
        VStack(alignment: .leading, spacing: 14) {
            if won || (solo && !(game.outcome?.text.isEmpty ?? true)) {
                VStack(alignment: .leading, spacing: 8) {
                    if won {
                        Label(solo ? "Great take" : "Round winner", systemImage: solo ? "star.fill" : "trophy.fill")
                            .font(.display(isLarge ? 16 : 13, .heavy))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Theme.night)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.goldFill, in: Capsule())
                    }
                    Text(game.outcome?.text ?? "")
                        .font(.display(isLarge ? 30 : 24, .black))
                        .foregroundStyle(won ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Color.white))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 14) {
                Avatar(player: player, size: isLarge ? 60 : 50)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(player.name)
                            .font(.display(isLarge ? 28 : 23, .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if won && !solo {
                            Text("+1")
                                .font(.display(14, .heavy))
                                .foregroundStyle(Theme.night)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.goldFill, in: Capsule())
                                .transition(.scale)
                        }
                    }
                    if let r = take?.result, !r.soundedLike.isEmpty {
                        Text("Sounded like \(r.soundedLike)")
                            .font(.system(size: isLarge ? 18 : 15, weight: .medium, design: .rounded))
                            .italic()
                            .foregroundStyle(Theme.subtext)
                    }
                }
                Spacer(minLength: 0)
                if take?.result != nil {
                    VStack(spacing: -4) {
                        Text("\(shownTotal)")
                            .font(.display(isLarge ? 54 : 44, .black))
                            .monospacedDigit()
                            .foregroundStyle(won ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Color.white))
                            .contentTransition(.numericText(value: Double(shownTotal)))
                        Text("pts").font(.display(13, .bold)).foregroundStyle(Theme.faint)
                    }
                }
            }

            if let r = take?.result {
                VStack(spacing: 9) {
                    if let m = r.manner { bar(take?.prompt.manner?.kind.label ?? "Mood", m) }
                    if let c = r.character { bar("Character", c) }
                    bar("Line", r.line)
                    bar("Flair", r.flair)
                }
                if !r.comment.isEmpty {
                    Text(r.comment)
                        .font(.system(size: isLarge ? 21 : 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !r.tip.isEmpty {
                    Label(r.tip, systemImage: "lightbulb.fill")
                        .font(.system(size: isLarge ? 18 : 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.subtext)
                }
                if !r.heard.isEmpty {
                    Label("“\(r.heard)”", systemImage: "quote.bubble.fill")
                        .font(.system(size: isLarge ? 17 : 14, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.faint)
                }
            } else if let error = take?.error {
                Text("The judge had trouble: \(error)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.coral)
                Button("Try judging again") { game.retryJudging(index) }
                    .buttonStyle(.glass(size: 16))
            }

            if let take {
                let playing = game.takePlayer.playingID == take.id
                Button {
                    game.takePlayer.toggle(id: take.id, audio: take.audio)
                } label: {
                    Label(playing ? "Stop" : "Hear it again", systemImage: playing ? "waveform" : "play.fill")
                        .symbolEffect(.variableColor.iterative, isActive: playing)
                }
                .buttonStyle(.glass(size: isLarge ? 18 : 16))
            }
        }
        .padding(isLarge ? 26 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(won ? AnyShapeStyle(LinearGradient(colors: [Theme.gold.opacity(0.2), Theme.amber.opacity(0.08)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Theme.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(won ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.stroke), lineWidth: won ? 2 : 1)
        )
        .shadow(color: won ? Theme.amber.opacity(0.35) : .clear, radius: 24, y: 8)
        .onAppear {
            guard let total = take?.result?.total else { return }
            withAnimation(.easeOut(duration: 1.1).delay(0.15 + Double(position) * 0.14)) { shownTotal = total }
        }
        .onChange(of: take?.result?.total) { _, total in
            withAnimation(.easeOut(duration: 0.8)) { shownTotal = total ?? 0 }
        }
    }

    private func bar(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.display(isLarge ? 17 : 14, .bold))
                .foregroundStyle(Theme.subtext)
                .frame(width: isLarge ? 110 : 86, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceStrong)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.coral, Theme.amber, Theme.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * Double(shownTotal > 0 ? value : 0) / 10)
                }
            }
            .frame(height: 10)
            Text("\(value)/10")
                .font(.display(isLarge ? 16 : 14, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.subtext)
                .lineLimit(1)
                .fixedSize()
                .frame(width: isLarge ? 60 : 48, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) out of 10")
    }
}

struct Scoreboard: View {
    let final: Bool
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        let ranked = game.standings(includeRound: !final)
        let multi = game.players.count > 1
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(final ? "Final standings" : "Scoreboard")
                    .font(.display(isLarge ? 24 : 20, .heavy))
                    .foregroundStyle(.white)
                ForEach(Array(ranked.enumerated()), id: \.element.id) { k, s in
                    let rank = ranked.firstIndex(where: { $0.score == s.score }).map { $0 + 1 } ?? k + 1
                    let lead = multi && s.score > 0 && s.score == ranked.first?.score
                    HStack(spacing: 12) {
                        Text(final && multi && rank <= 3 ? ["🥇", "🥈", "🥉"][rank - 1] : "\(rank)")
                            .font(.display(isLarge ? 20 : 17, .heavy))
                            .foregroundStyle(lead ? Theme.gold : Theme.faint)
                            .frame(width: 30)
                        Avatar(player: game.players[s.index], size: isLarge ? 40 : 34)
                        Text(s.name)
                            .font(.display(isLarge ? 21 : 18, lead ? .heavy : .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if multi { Trophies(count: s.wins, size: 13) }
                        Spacer()
                        Text("\(s.score)")
                            .font(.display(isLarge ? 24 : 20, .black))
                            .monospacedDigit()
                            .foregroundStyle(lead ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Color.white))
                            .contentTransition(.numericText(value: Double(s.score)))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(lead ? Theme.gold.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
