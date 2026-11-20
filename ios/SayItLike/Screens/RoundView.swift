import SwiftUI

struct RoundView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge
    @State private var confirmEnd = false
    @State private var writingPrompt = false

    private var player: Player { game.players[game.currentPlayer] }
    private var focusMode: Bool {
        switch game.stage {
        case .announcing, .recording: true
        default: false
        }
    }

    var body: some View {
        VStack(spacing: isLarge ? 22 : 14) {
            RoundHeader(confirmEnd: $confirmEnd)
            if game.players.count > 1 && !focusMode {
                LineupStrip()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            PromptCard(prompt: game.prompt)
                .id(game.prompt)
                .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                .frame(maxHeight: .infinity)
            stagePanel
                .frame(minHeight: isLarge ? 300 : 230)
        }
        .padding(.horizontal, isLarge ? 40 : 18)
        .padding(.bottom, isLarge ? 24 : 8)
        .frame(maxWidth: isLarge ? 960 : .infinity)
        .frame(maxWidth: .infinity)
        .confirmationDialog("End this game?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End game", role: .destructive) { game.endGame() }
        } message: {
            Text("Scores and this round's recordings will be cleared.")
        }
        .sheet(isPresented: $writingPrompt) { CustomPromptSheet() }
    }

    @ViewBuilder private var stagePanel: some View {
        switch game.stage {
        case .ready: readyPanel.transition(.blurReplace)
        case .announcing: AnnouncingPanel(player: player).transition(.blurReplace)
        case .recording(let start, let seconds): RecordingPanel(start: start, seconds: seconds).transition(.blurReplace)
        case .review: reviewPanel.transition(.blurReplace)
        }
    }

    // MARK: ready

    private var readyPanel: some View {
        VStack(spacing: isLarge ? 20 : 14) {
            HStack(spacing: 14) {
                Avatar(player: player, size: isLarge ? 72 : 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.players.count > 1 ? "\(player.name), you're up!" : "Your turn!")
                        .font(.display(isLarge ? 40 : 30, .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("You'll have \(Int(game.recordSeconds)) seconds after “Action!”")
                        .font(.system(size: isLarge ? 20 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.subtext)
                        .contentTransition(.numericText(value: game.recordSeconds))
                }
                Spacer(minLength: 0)
            }
            .id(game.currentPlayer)
            .transition(.push(from: .trailing))

            if game.canChangePrompt {
                HStack(spacing: 10) {
                    Button {
                        Haptics.tick()
                        game.newPrompt()
                    } label: {
                        Label("New prompt", systemImage: "dice.fill")
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        writingPrompt = true
                    } label: {
                        Label("Write your own", systemImage: "pencil.line")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass(size: isLarge ? 19 : 16))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Button {
                game.beginTurn()
            } label: {
                Label("I'm ready!", systemImage: "movieclapper.fill")
            }
            .buttonStyle(.primary(size: isLarge ? 30 : 24))
        }
    }

    // MARK: review

    private var reviewPanel: some View {
        let take = game.takes[game.currentPlayer]
        let next = game.nextPlayer.map { game.players[$0] }
        return VStack(spacing: isLarge ? 18 : 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.mint)
                    .symbolEffect(.bounce, value: game.turn)
                Text("That's a wrap, \(player.name)!")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(.display(isLarge ? 38 : 28, .black))
            .foregroundStyle(.white)

            judgeStatus(take)

            if let take {
                let playing = game.takePlayer.playingID == take.id
                Button {
                    game.takePlayer.toggle(id: take.id, audio: take.audio)
                } label: {
                    Label(playing ? "Stop" : "Hear it back", systemImage: playing ? "stop.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass(size: isLarge ? 20 : 17))
            }

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                game.passPhone()
            } label: {
                if let next {
                    HStack(spacing: 12) {
                        Text("Pass to \(next.name)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "arrow.right")
                    }
                } else {
                    Label("See the results", systemImage: "trophy.fill")
                }
            }
            .buttonStyle(next == nil ? PrimaryButtonStyle(fill: AnyShapeStyle(Theme.goldFill), size: isLarge ? 30 : 24)
                                     : PrimaryButtonStyle(size: isLarge ? 30 : 24))
        }
    }

    @ViewBuilder private func judgeStatus(_ take: Take?) -> some View {
        HStack(spacing: 8) {
            if take?.error != nil {
                Image(systemName: "exclamationmark.bubble")
                Text("The judge had a hiccup. You can retry on the results screen.")
            } else if take?.settled == true {
                Image(systemName: "ear.badge.checkmark")
                Text("The judge has heard it. Scores at the end of the round!")
            } else {
                ProgressView().tint(Theme.subtext).controlSize(.small)
                Text("The judge is listening…")
            }
        }
        .font(.system(size: isLarge ? 18 : 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.subtext)
        .multilineTextAlignment(.center)
    }
}

// MARK: - Header and lineup

private struct RoundHeader: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge
    @Binding var confirmEnd: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Round \(game.round) of \(game.totalRounds)", color: Theme.subtext, size: isLarge ? 16 : 13)
                if game.totalRounds <= 20 {
                    HStack(spacing: 5) {
                        ForEach(1...game.totalRounds, id: \.self) { r in
                            Capsule()
                                .fill(r < game.round ? AnyShapeStyle(Theme.gold.opacity(0.75))
                                      : r == game.round ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.surfaceStrong))
                                .frame(width: r == game.round ? 22 : 9, height: 7)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            Spacer()
            Menu {
                Button("Settings", systemImage: "gearshape") { game.showSettings = true }
                Button("End game", systemImage: "xmark.circle", role: .destructive) { confirmEnd = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.subtext)
                    .frame(width: 44, height: 44)
                    .background(Theme.surfaceStrong, in: Circle())
            }
            .accessibilityLabel("Game menu")
        }
        .padding(.top, 6)
    }
}

private struct LineupStrip: View {
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(game.order.enumerated()), id: \.offset) { pos, i in
                        chip(pos: pos, player: game.players[i]).id(pos)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: game.turn) { _, t in withAnimation { proxy.scrollTo(t, anchor: .center) } }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Turn order")
    }

    private func chip(pos: Int, player: Player) -> some View {
        let now = pos == game.turn
        let done = pos < game.turn
        return HStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(player: player, size: isLarge ? 34 : 28)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white, Theme.mint)
                        .offset(x: 3, y: 3)
                }
            }
            Text(player.name)
                .font(.display(isLarge ? 18 : 15, now ? .heavy : .semibold))
                .foregroundStyle(now ? .white : Theme.subtext)
                .lineLimit(1)
            Trophies(count: player.wins, size: 11)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(now ? player.color.opacity(0.28) : Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(now ? player.color : Theme.stroke, lineWidth: now ? 2 : 1))
        .opacity(done ? 0.6 : 1)
        .animation(.snappy, value: game.turn)
    }
}

// MARK: - Prompt card

struct PromptCard: View {
    let prompt: Prompt
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        VStack(spacing: isLarge ? 20 : 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                Text("SAY")
            }
            .font(.display(isLarge ? 18 : 14, .heavy))
            .tracking(2)
            .foregroundStyle(Theme.faint)

            Text("“\(prompt.line)”")
                .font(.script(isLarge ? 86 : 40))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineSpacing(2)

            Text(prompt.direction)
                .font(.display(isLarge ? 64 : 31, .heavy))
                .foregroundStyle(Theme.goldFill)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, isLarge ? 36 : 20)
        .padding(.vertical, isLarge ? 34 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: isLarge ? 40 : 32, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.11), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isLarge ? 40 : 32, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Theme.gold.opacity(0.55), Theme.magenta.opacity(0.35), Theme.violet.opacity(0.3)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: Theme.violet.opacity(0.25), radius: 30, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Say: \(prompt.line). \(prompt.direction).")
    }
}

// MARK: - Lights, camera, action

private struct AnnouncingPanel: View {
    let player: Player
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        VStack(spacing: isLarge ? 22 : 14) {
            if game.cue == .getReady {
                VStack(spacing: 4) {
                    Text("Get ready,")
                        .font(.display(isLarge ? 34 : 26, .bold))
                        .foregroundStyle(Theme.subtext)
                    Text(player.name)
                        .font(.display(isLarge ? 84 : 58, .black))
                        .foregroundStyle(LinearGradient(colors: [.white, player.color.mix(with: .white, by: 0.3)],
                                                        startPoint: .top, endPoint: .bottom))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .shadow(color: player.color.opacity(0.6), radius: 20)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                HStack(spacing: isLarge ? 26 : 14) {
                    word("Lights", lit: game.cue != .getReady, current: game.cue == .lights)
                    Circle().fill(Theme.faint).frame(width: 8, height: 8)
                    word("Camera", lit: game.cue == .camera || game.cue == .action, current: game.cue == .camera)
                }
                Text("ACTION!")
                    .font(.display(isLarge ? 96 : 64, .black))
                    .foregroundStyle(game.cue == .action ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.surfaceStrong))
                    .scaleEffect(game.cue == .action ? 1.08 : 0.9)
                    .shadow(color: game.cue == .action ? Theme.amber.opacity(0.8) : .clear, radius: 26)
                    .animation(.spring(duration: 0.35, bounce: 0.5), value: game.cue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func word(_ text: String, lit: Bool, current: Bool) -> some View {
        Text(text)
            .font(.display(isLarge ? 54 : 36, .black))
            .foregroundStyle(lit ? .white : Theme.surfaceStrong)
            .scaleEffect(current ? 1.1 : 1)
            .shadow(color: current ? .white.opacity(0.6) : .clear, radius: 16)
            .animation(.spring(duration: 0.3, bounce: 0.45), value: current)
    }
}

// MARK: - Recording

private struct RecordingPanel: View {
    let start: Date
    let seconds: Double
    @Environment(GameModel.self) private var game
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        let ring: CGFloat = isLarge ? 230 : 168
        HStack(spacing: isLarge ? 40 : 22) {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let remaining = max(0, seconds - elapsed)
                let level = game.recorder.level()
                let urgent = remaining <= 3
                ZStack {
                    Circle()
                        .fill(Theme.rec.opacity(0.16 + level * 0.32))
                        .scaleEffect(0.72 + level * 0.26)
                        .blur(radius: 6)
                    Circle()
                        .stroke(Theme.surfaceStrong, lineWidth: isLarge ? 16 : 12)
                    Circle()
                        .trim(from: 0, to: remaining / seconds)
                        .stroke(urgent ? AnyShapeStyle(Theme.rec) : AnyShapeStyle(Theme.goldFill),
                                style: StrokeStyle(lineWidth: isLarge ? 16 : 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -4) {
                        Text("\(Int(remaining.rounded(.up)))")
                            .font(.display(isLarge ? 96 : 70, .black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: Int(remaining.rounded(.up)))
                        Text("sec")
                            .font(.display(isLarge ? 20 : 15, .bold))
                            .foregroundStyle(Theme.subtext)
                    }
                }
                .frame(width: ring, height: ring)
            }

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Circle().fill(Theme.rec).frame(width: 12, height: 12)
                        .phaseAnimator([1.0, 0.3]) { c, o in c.opacity(o) } animation: { _ in .easeInOut(duration: 0.6) }
                    Text("Recording")
                }
                .font(.display(isLarge ? 22 : 17, .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.rec.opacity(0.22), in: Capsule())

                Button {
                    game.finishRecording()
                } label: {
                    Label("Done", systemImage: "stop.fill")
                        .frame(minWidth: isLarge ? 170 : 110)
                }
                .buttonStyle(.glass(size: isLarge ? 24 : 20))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Custom prompt

private struct CustomPromptSheet: View {
    @Environment(GameModel.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var line = ""
    @State private var mood = ""
    @State private var character = ""

    private var valid: Bool {
        !line.trimmed.isEmpty && (!mood.trimmed.isEmpty || !character.trimmed.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("I sure do hope the weather doesn't get worse.", text: $line, axis: .vertical)
                        .lineLimit(2...4)
                } header: { Text("The line") }
                Section {
                    TextField("Mood, e.g. sleepy", text: $mood)
                    TextField("Character, e.g. cowboy", text: $character)
                } header: { Text("How to say it") } footer: {
                    if !mood.trimmed.isEmpty || !character.trimmed.isEmpty {
                        Text("Say it \(Prompt.direction(manner: mood.trimmed.isEmpty ? nil : Manner(kind: .mood, text: mood.trimmed), character: character.trimmed.isEmpty ? nil : character.trimmed))")
                    } else {
                        Text("Add a mood, a character, or both.")
                    }
                }
            }
            .navigationTitle("Write your own")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        game.useCustomPrompt(line: String(line.trimmed.prefix(200)), mood: String(mood.trimmed.prefix(60)),
                                             character: String(character.trimmed.prefix(80)))
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
