import SwiftUI

struct SetupView: View {
    @Environment(GameModel.self) private var game
    @Environment(AppSettings.self) private var settings
    @Environment(\.isLarge) private var isLarge

    struct NameField: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }

    @State private var names: [NameField] = []
    @State private var starting = false
    @FocusState private var focused: UUID?

    private var cleanNames: [String] { GameModel.cleanNames(names.map(\.text)) }
    private var canStart: Bool { !cleanNames.isEmpty && settings.hasAPIKey && !starting }

    var body: some View {
        @Bindable var settings = settings
        List {
            Section {
                hero
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 4, trailing: 4))

            if !settings.hasAPIKey {
                Section { keyBanner }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section {
                ForEach($names) { $field in
                    playerRow($field)
                }
                .onMove { names.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { names.remove(atOffsets: $0) }

                if names.count < GameModel.maxPlayers {
                    Button {
                        let field = NameField(text: "")
                        withAnimation { names.append(field) }
                        focused = field.id
                    } label: {
                        Label("Add a player", systemImage: "plus.circle.fill")
                            .font(.display(19, .bold))
                            .foregroundStyle(Theme.gold)
                            .padding(.vertical, 6)
                    }
                }
            } header: {
                sectionHeader("Who's playing?", detail: names.count > 1 ? "Hold and drag to reorder" : nil)
            }
            .listRowBackground(Theme.surface)

            Section {
                difficultyPicker
            } header: {
                sectionHeader("Difficulty", detail: nil)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            Section {
                roundsPicker
            } header: {
                sectionHeader("Rounds", detail: nil)
            }
            .listRowBackground(Theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.defaultMinListRowHeight, 58)
        .frame(maxWidth: isLarge ? 720 : .infinity)
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) { startBar }
        .onAppear {
            if names.isEmpty {
                let saved = settings.savedNames
                names = (saved.isEmpty ? ["", ""] : saved).map { NameField(text: $0) }
            }
            starting = false
        }
    }

    // MARK: pieces

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                LogoTitle(size: isLarge ? 38 : 30)
                Spacer()
                Button {
                    game.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.subtext)
                        .frame(width: 46, height: 46)
                        .background(Theme.surfaceStrong, in: Circle())
                }
                .accessibilityLabel("Settings")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Same line. Different voices.")
                    .font(.display(isLarge ? 40 : 30, .black))
                    .foregroundStyle(.white)
                Text("Who sells it best?")
                    .font(.display(isLarge ? 40 : 30, .black))
                    .foregroundStyle(Theme.brand)
            }
            .padding(.top, 10)
            Text("Everyone gets the same words and a way to say them. An AI judge listens to each performance. Win rounds, collect trophies, take the crown.")
                .font(.system(size: isLarge ? 20 : 17, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private var keyBanner: some View {
        Button {
            game.showSettings = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.night)
                    .frame(width: 44, height: 44)
                    .background(Theme.goldFill, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your OpenAI API key")
                        .font(.display(18, .heavy))
                        .foregroundStyle(.white)
                    Text("The judge and announcer need it. Tap to open Settings.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.subtext)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.faint)
            }
            .padding(16)
            .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.display(isLarge ? 24 : 21, .heavy))
                .foregroundStyle(.white)
                .textCase(nil)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.faint)
                    .textCase(nil)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private func playerRow(_ field: Binding<NameField>) -> some View {
        let index = names.firstIndex(where: { $0.id == field.wrappedValue.id }) ?? 0
        let preview = Player(name: field.wrappedValue.text.isEmpty ? "\(index + 1)" : field.wrappedValue.text, colorIndex: index)
        let placeholders = ["Grandpa", "Ava", "Leo", "Mom", "Dad", "Grandma"]
        return HStack(spacing: 14) {
            Avatar(player: preview, size: 40)
            TextField(index < placeholders.count ? placeholders[index] : "Player \(index + 1)", text: field.text)
                .font(.display(isLarge ? 24 : 21, .bold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focused, equals: field.wrappedValue.id)
                .onSubmit {
                    if let i = names.firstIndex(where: { $0.id == field.wrappedValue.id }), i + 1 < names.count {
                        focused = names[i + 1].id
                    } else {
                        focused = nil
                    }
                }
            if names.count > 1 {
                Button {
                    withAnimation { names.removeAll { $0.id == field.wrappedValue.id } }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove player")
            }
        }
        .padding(.vertical, 4)
    }

    private var difficultyPicker: some View {
        HStack(spacing: 10) {
            ForEach(Difficulty.allCases) { d in
                let on = settings.difficulty == d
                Button {
                    Haptics.tick()
                    withAnimation(.snappy) { settings.difficulty = d }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: d.symbol)
                            .font(.system(size: isLarge ? 30 : 26, weight: .semibold))
                            .foregroundStyle(on ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.subtext))
                        Text(d.title)
                            .font(.display(isLarge ? 21 : 18, .heavy))
                            .foregroundStyle(.white)
                        Text(d.subtitle)
                            .font(.system(size: isLarge ? 14 : 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.subtext)
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background(on ? Theme.surfaceStrong : Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(on ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.stroke), lineWidth: on ? 2.5 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var roundsPicker: some View {
        HStack(spacing: 16) {
            Text("\(settings.rounds)")
                .font(.display(isLarge ? 46 : 40, .black))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(settings.rounds)))
                .frame(minWidth: 56, alignment: .leading)
            Text(settings.rounds == 1 ? "round" : "rounds")
                .font(.display(19, .bold))
                .foregroundStyle(Theme.subtext)
            Spacer()
            HStack(spacing: 10) {
                stepButton("minus", enabled: settings.rounds > 1) { settings.rounds -= 1 }
                stepButton("plus", enabled: settings.rounds < 20) { settings.rounds += 1 }
            }
        }
        .padding(.vertical, 6)
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tick()
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Theme.surfaceStrong, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(symbol == "plus" ? "More rounds" : "Fewer rounds")
    }

    private var startBar: some View {
        BottomBar(maxWidth: isLarge ? 560 : .infinity) {
            Button {
                start()
            } label: {
                HStack(spacing: 10) {
                    if starting { ProgressView().tint(.white) }
                    Text(cleanNames.count == 1 ? "Play solo" : "Let's play!")
                    Image(systemName: "sparkles")
                }
            }
            .buttonStyle(.primary(size: isLarge ? 26 : 22))
            .disabled(!canStart)
        }
    }

    private func start() {
        let list = cleanNames
        guard !list.isEmpty else { return }
        focused = nil
        starting = true
        settings.savedNames = list
        Haptics.tap()
        Task {
            await game.startGame(names: list, rounds: settings.rounds, difficulty: settings.difficulty)
            starting = false
        }
    }
}
