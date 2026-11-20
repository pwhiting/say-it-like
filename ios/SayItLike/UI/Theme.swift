import SwiftUI
import UIKit

enum Theme {
    static let plum = Color(hex: 0x24124A)
    static let night = Color(hex: 0x0C0720)
    static let violet = Color(hex: 0x7C5CFF)
    static let magenta = Color(hex: 0xE83E8C)
    static let coral = Color(hex: 0xFF5E5B)
    static let amber = Color(hex: 0xFF9F1C)
    static let gold = Color(hex: 0xFFC94A)
    static let mint = Color(hex: 0x2ED1A2)
    static let rec = Color(hex: 0xFF3B4E)

    static let text = Color.white
    static let subtext = Color.white.opacity(0.7)
    static let faint = Color.white.opacity(0.45)
    static let surface = Color.white.opacity(0.075)
    static let surfaceStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.13)

    static let playerColors: [Color] = [
        0xFF7A45, 0x3AA0FF, 0x9B6BFF, 0x14C3B0, 0xFF4F8B, 0x3DCB6C,
        0xFFB020, 0x5B7CFF, 0xD65BFF, 0xFF6B6B, 0x00B8D9, 0xA3D930,
    ].map { Color(hex: $0) }

    static let primary = LinearGradient(colors: [coral, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let goldFill = LinearGradient(colors: [Color(hex: 0xFFE08A), gold, amber], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let brand = LinearGradient(colors: [violet, magenta, amber], startPoint: .leading, endPoint: .trailing)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

extension Font {
    /// Friendly, heavy rounded type for headings and UI.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Serif type for the line being performed, like a script.
    static func script(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

/// Deep stage background with soft colored spotlights.
struct StageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.plum, Theme.night], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.violet.opacity(0.42), .clear], center: UnitPoint(x: 0.12, y: -0.04),
                           startRadius: 0, endRadius: 560)
            RadialGradient(colors: [Theme.magenta.opacity(0.26), .clear], center: UnitPoint(x: 0.96, y: 0.02),
                           startRadius: 0, endRadius: 480)
            RadialGradient(colors: [Theme.amber.opacity(0.12), .clear], center: UnitPoint(x: 0.5, y: 1.08),
                           startRadius: 0, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func action() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.primary)
    var size: CGFloat = 22
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(size, .heavy))
            .frame(maxWidth: .infinity)
            .padding(.vertical, size * 0.82)
            .padding(.horizontal, 24)
            .foregroundStyle(isEnabled ? Color.white : Theme.faint)
            .background(isEnabled ? fill : AnyShapeStyle(Color(hex: 0x2B2148)), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(isEnabled ? 0.22 : 0.1), lineWidth: 1))
            .shadow(color: Theme.magenta.opacity(isEnabled ? 0.45 : 0), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var size: CGFloat = 17
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(size, .bold))
            .foregroundStyle(Theme.text)
            .padding(.vertical, size * 0.72)
            .padding(.horizontal, size * 1.1)
            .background(Theme.surfaceStrong, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(size: CGFloat) -> PrimaryButtonStyle { PrimaryButtonStyle(size: size) }
    static var gold: PrimaryButtonStyle { PrimaryButtonStyle(fill: AnyShapeStyle(Theme.goldFill)) }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static func glass(size: CGFloat) -> GlassButtonStyle { GlassButtonStyle(size: size) }
}

// MARK: - Cards and small pieces

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.faint
    var size: CGFloat = 14
    var body: some View {
        Text(text.uppercased())
            .font(.display(size, .bold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

struct Avatar: View {
    let player: Player
    var size: CGFloat = 44

    var body: some View {
        Text(player.initial)
            .font(.display(size * 0.46, .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(LinearGradient(colors: [player.color.opacity(0.95), player.color.mix(with: .black, by: 0.25)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: max(1, size / 30)))
            .shadow(color: player.color.opacity(0.45), radius: size / 6, y: size / 14)
            .accessibilityHidden(true)
    }
}

struct Trophies: View {
    let count: Int
    var size: CGFloat = 15
    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                if count <= 4 {
                    ForEach(0..<count, id: \.self) { _ in Image(systemName: "trophy.fill") }
                } else {
                    Image(systemName: "trophy.fill")
                    Text("×\(count)").font(.display(size, .heavy))
                }
            }
            .font(.system(size: size))
            .foregroundStyle(Theme.goldFill)
            .accessibilityLabel("\(count) round win\(count == 1 ? "" : "s")")
        }
    }
}

struct LogoTitle: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(spacing: size * 0.35) {
            Image("LogoMark")
                .resizable()
                .frame(width: size * 1.35, height: size * 1.35)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
                .shadow(color: Theme.magenta.opacity(0.4), radius: 8, y: 3)
            Text("Say It Like")
                .font(.display(size, .black))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Say It Like")
    }
}

/// True on iPad-sized layouts; used to scale type up for reading across a room.
struct IsLargeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isLarge: Bool {
        get { self[IsLargeKey.self] }
        set { self[IsLargeKey.self] = newValue }
    }
}

/// Bottom action bar that fades the scrolling content out behind its buttons.
struct BottomBar<Content: View>: View {
    var maxWidth: CGFloat = .infinity
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: maxWidth)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(stops: [.init(color: Theme.night.opacity(0), location: 0),
                                       .init(color: Theme.night.opacity(0.94), location: 0.42),
                                       .init(color: Theme.night, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
    }
}
