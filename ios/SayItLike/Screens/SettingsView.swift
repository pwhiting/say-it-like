import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var keyDraft = ""
    @State private var revealKey = false
    @State private var keyStatus: KeyStatus = .idle

    enum KeyStatus: Equatable { case idle, checking, ok, failed(String) }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Group {
                            if revealKey {
                                TextField("sk-…", text: $keyDraft)
                            } else {
                                SecureField("sk-…", text: $keyDraft)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(saveKey)
                        Button {
                            revealKey.toggle()
                        } label: {
                            Image(systemName: revealKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(revealKey ? "Hide key" : "Show key")
                    }
                    HStack {
                        Button("Save and test", action: saveKey)
                            .disabled(keyDraft.trimmed.isEmpty || keyStatus == .checking)
                        Spacer()
                        keyStatusView
                    }
                    if settings.hasAPIKey {
                        Button("Remove key", role: .destructive) {
                            keyDraft = ""
                            settings.apiKey = ""
                            keyStatus = .idle
                        }
                    }
                } header: {
                    Text("OpenAI API key")
                } footer: {
                    Text("Used for the judge and the announcer. Stored in this device's Keychain and sent only to OpenAI. Create a key at platform.openai.com/api-keys.")
                }

                Section {
                    Toggle("Announcer voice", isOn: $settings.announcerOn)
                    if settings.announcerOn {
                        NavigationLink {
                            VoicePicker()
                        } label: {
                            LabeledContent("Voice", value: AnnouncerVoice.all.first { $0.id == settings.voice }?.name ?? settings.voice)
                        }
                    }
                } header: {
                    Text("Announcer")
                } footer: {
                    Text("Calls each player up with “Lights, camera, action!” and announces the winners. Lines are made with OpenAI's voices when the game starts.")
                }

                Section {
                    Picker("Recording time", selection: $settings.pace) {
                        ForEach(TimerPace.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Recording time")
                } footer: {
                    Text(settings.pace.detail + " Easy rounds and slow directions (like “in slow motion”) get extra time automatically.")
                }

                Section {
                    Toggle("Sound effects", isOn: $settings.soundEffects)
                } footer: {
                    Text("Fanfares, ticks and the drumroll. Never played while someone is recording.")
                }

                Section {
                    LabeledContent("Judge model") {
                        TextField(Judge.defaultModel, text: $settings.judgeModel)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Voice model") {
                        TextField(AppSettings.defaultSpeechModel, text: $settings.speechModel)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button("Reset models") {
                        settings.judgeModel = Judge.defaultModel
                        settings.speechModel = AppSettings.defaultSpeechModel
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("The judge must accept audio input and function calling in the Responses API.")
                }

                Section {
                    Label("Each take is kept in memory only until the round's results are shown, then deleted. Nothing is saved to the device.", systemImage: "lock.fill")
                    Label("Recordings are sent to OpenAI for scoring and follow your OpenAI account's data terms. Get a parent's OK before recording children.", systemImage: "info.circle")
                } header: {
                    Text("Privacy")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { keyDraft = settings.apiKey }
        }
    }

    @ViewBuilder private var keyStatusView: some View {
        switch keyStatus {
        case .idle:
            if settings.hasAPIKey {
                Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
            }
        case .checking:
            ProgressView()
        case .ok:
            Label("Key works", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.mint)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.coral)
                .lineLimit(2)
        }
    }

    private func saveKey() {
        let key = keyDraft.trimmed
        guard !key.isEmpty else { return }
        settings.apiKey = key
        keyStatus = .checking
        Task {
            do {
                try await OpenAI.checkKey(key)
                keyStatus = .ok
            } catch {
                keyStatus = .failed(error.localizedDescription)
            }
        }
    }
}

/// Pick the announcer's voice, with a sample of each.
private struct VoicePicker: View {
    @Environment(AppSettings.self) private var settings
    @Environment(GameModel.self) private var game
    @State private var loading: String?
    @State private var samples: [String: Data] = [:]
    @State private var error: String?

    var body: some View {
        List {
            Section {
                ForEach(AnnouncerVoice.all) { v in
                    HStack(spacing: 14) {
                        Button {
                            settings.voice = v.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(.headline)
                                    Text(v.blurb).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.voice == v.id {
                                    Image(systemName: "checkmark").font(.headline).foregroundStyle(Theme.coral)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            preview(v)
                        } label: {
                            Group {
                                if loading == v.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "play.circle.fill").font(.title2)
                                }
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!settings.hasAPIKey || loading != nil)
                        .accessibilityLabel("Play a sample of \(v.name)")
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                if let error {
                    Text(error).foregroundStyle(Theme.coral)
                } else if !settings.hasAPIKey {
                    Text("Add your API key to hear samples.")
                } else {
                    Text("Tap ▶︎ to hear a sample. Some voices need the gpt-4o-mini-tts voice model.")
                }
            }
        }
        .navigationTitle("Announcer voice")
        .onDisappear { game.announcer.stop() }
    }

    private func preview(_ v: AnnouncerVoice) {
        if let data = samples[v.id] {
            Task { await game.announcer.play(data) }
            return
        }
        loading = v.id
        error = nil
        AudioSession.configure()
        Task {
            do {
                let data = try await OpenAI.speech(text: "Hi, I'm \(v.name)! Get ready... Lights! Camera! Action!",
                                                   voice: v.id, model: settings.effectiveSpeechModel,
                                                   instructions: Announcer.instructions, apiKey: settings.trimmedKey)
                samples[v.id] = data
                loading = nil
                await game.announcer.play(data)
            } catch {
                self.error = error.localizedDescription
                loading = nil
            }
        }
    }
}
