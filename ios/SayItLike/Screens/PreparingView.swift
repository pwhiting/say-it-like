import SwiftUI

/// "Setting the stage…" while the announcer's lines are generated for this game's players.
struct PreparingView: View {
    @Environment(GameModel.self) private var game
    @Environment(AppSettings.self) private var settings
    @Environment(\.isLarge) private var isLarge

    var body: some View {
        VStack(spacing: isLarge ? 34 : 26) {
            Spacer()
            Image("LogoMark")
                .resizable()
                .frame(width: isLarge ? 170 : 130, height: isLarge ? 170 : 130)
                .clipShape(RoundedRectangle(cornerRadius: isLarge ? 40 : 30, style: .continuous))
                .shadow(color: Theme.magenta.opacity(0.55), radius: 40)
                .phaseAnimator([1.0, 1.05]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.9) }

            VStack(spacing: 8) {
                Text("Setting the stage…")
                    .font(.display(isLarge ? 44 : 34, .black))
                    .foregroundStyle(.white)
                Text(settings.announcerOn ? "Warming up the announcer" : "Lights are coming up")
                    .font(.system(size: isLarge ? 21 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.subtext)
            }

            HStack(spacing: isLarge ? 18 : 12) {
                ForEach(game.players) { p in
                    let ready = !settings.announcerOn || game.announcer.readyNames.contains(p.name)
                    VStack(spacing: 6) {
                        Avatar(player: p, size: isLarge ? 58 : 44)
                            .overlay(alignment: .bottomTrailing) {
                                if ready {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white, Theme.mint)
                                        .transition(.scale)
                                }
                            }
                            .opacity(ready ? 1 : 0.5)
                        Text(p.name)
                            .font(.display(isLarge ? 15 : 12, .bold))
                            .foregroundStyle(Theme.subtext)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: isLarge ? 80 : 60)
                    .animation(.spring, value: ready)
                }
            }
            .padding(.horizontal)
            Spacer()
            Button("Cancel") { game.endGame() }
                .buttonStyle(.glass)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
}
