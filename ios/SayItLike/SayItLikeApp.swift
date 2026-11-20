import SwiftUI

@main
struct SayItLikeApp: App {
    @State private var settings: AppSettings
    @State private var game: GameModel

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _game = State(initialValue: GameModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(game)
                .preferredColorScheme(.dark)
                .tint(Theme.coral)
        }
    }
}

struct RootView: View {
    @Environment(GameModel.self) private var game
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        @Bindable var game = game
        ZStack {
            StageBackground()
            Group {
                switch game.phase {
                case .setup: SetupView()
                case .preparing: PreparingView()
                case .round: RoundView()
                case .results: ResultsView()
                case .final: FinalView()
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            ConfettiOverlay(burst: game.confettiBurst, power: game.confettiPower)
        }
        .environment(\.isLarge, hSize == .regular && vSize == .regular)
        .sheet(isPresented: $game.showSettings) { SettingsView() }
        .alert("Heads up", isPresented: Binding(get: { game.alert != nil }, set: { if !$0 { game.alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(game.alert ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.interrupt() }
        }
        .onChange(of: game.phase, initial: true) { _, phase in
            // Keep the screen awake while the phone is being passed around.
            UIApplication.shared.isIdleTimerDisabled = phase != .setup
        }
        .task {
            AudioSession.configure()
            #if DEBUG
            game.loadDemoIfRequested()
            #endif
        }
    }
}
