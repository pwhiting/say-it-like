import SwiftUI

/// Confetti fired from both bottom corners whenever `burst` changes. Skipped when the device
/// asks for reduced motion.
struct ConfettiOverlay: View {
    let burst: Int
    let power: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bursts: [Burst] = []

    private static let life = 3.4
    private static let colors: [Color] = [Theme.gold, Color(hex: 0xFFD76A), Theme.coral, Theme.amber,
                                          Color(hex: 0x3AA0FF), Theme.magenta, Theme.mint, Theme.violet]

    struct Piece {
        let left: Bool
        let angle: Double   // radians from vertical, toward the middle
        let speed: Double   // fraction of screen height per second
        let w, h: Double
        let spin: Double
        let flip: Double
        let delay: Double
        let color: Color
    }

    struct Burst: Identifiable {
        let id = UUID()
        let start = Date()
        let pieces: [Piece]
    }

    var body: some View {
        TimelineView(.animation(paused: bursts.isEmpty)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date
                for burst in bursts {
                    draw(burst, at: now.timeIntervalSince(burst.start), in: &ctx, size: size)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onChange(of: burst) {
            guard !reduceMotion else { return }
            let n = Int(150 * power)
            let pieces = (0..<n).map { k in
                Piece(left: k.isMultiple(of: 2),
                      angle: 0.22 + Double.random(in: 0...0.55),
                      speed: 1.55 + Double.random(in: 0...0.95),
                      w: 7 + Double.random(in: 0...6), h: 10 + Double.random(in: 0...8),
                      spin: Double.random(in: -7...7), flip: 5 + Double.random(in: 0...9),
                      delay: Double.random(in: 0...0.18),
                      color: Self.colors[k % Self.colors.count])
            }
            let b = Burst(pieces: pieces)
            bursts.append(b)
            Task {
                try? await Task.sleep(for: .seconds(Self.life + 0.3))
                bursts.removeAll { $0.id == b.id }
            }
        }
    }

    private func draw(_ burst: Burst, at elapsed: Double, in ctx: inout GraphicsContext, size: CGSize) {
        let H = size.height, W = size.width
        let k = 1.25            // air drag
        let g = 1.9 * H         // gravity, points per second squared
        let fade = max(0, min(1, (Self.life - elapsed) / 0.8))
        for p in burst.pieces {
            let t = elapsed - p.delay
            guard t > 0 else { continue }
            let decay = (1 - exp(-k * t)) / k
            let dir = p.left ? 1.0 : -1.0
            let vx = sin(p.angle) * p.speed * H * dir * (W / H) * 0.75
            let vy = -cos(p.angle) * p.speed * H
            let x = (p.left ? -10 : W + 10) + vx * decay
            let y = H * 0.96 + (vy + g / k) * decay - g * t / k
            guard y < H + 40 else { continue }
            var piece = ctx
            piece.opacity = fade
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(p.spin * t))
            piece.scaleBy(x: 1, y: cos(p.flip * t))
            piece.fill(Path(CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)), with: .color(p.color))
        }
    }
}
