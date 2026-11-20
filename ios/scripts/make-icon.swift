// Draws the Say It Like app icon (1024×1024) and the in-app logo from the same artwork.
//
//   swift ios/scripts/make-icon.swift
//
// Writes:
//   ios/SayItLike/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//   ios/SayItLike/Assets.xcassets/LogoMark.imageset/LogoMark.png

import AppKit
import CoreGraphics
import CoreText
import Foundation

let size: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
               colors: stops.map { rgb($0.0, $0.1) } as CFArray,
               locations: stops.map { $0.2 })!
}

// A four-pointed sparkle centered on (cx, cy).
func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let k = r * 0.16
    p.move(to: CGPoint(x: cx, y: cy - r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + k, y: cy - k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + k, y: cy + k))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - k, y: cy + k))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - k, y: cy - k))
    p.closeSubpath()
    return p
}

// Speech bubble: a soft rounded rectangle with a tail sweeping down and to the left.
func bubble() -> CGPath {
    let rect = CGRect(x: 168, y: 214, width: 688, height: 486)
    let p = CGMutablePath()
    p.addRoundedRect(in: rect, cornerWidth: 168, cornerHeight: 168)
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: 300, y: 640))
    tail.addCurve(to: CGPoint(x: 226, y: 846), control1: CGPoint(x: 300, y: 730), control2: CGPoint(x: 276, y: 800))
    tail.addCurve(to: CGPoint(x: 470, y: 690), control1: CGPoint(x: 330, y: 820), control2: CGPoint(x: 420, y: 760))
    tail.closeSubpath()
    return p.union(tail)
}

// The “ ” glyphs as a path, centered in `box` (top-left origin, y down).
func quotes(in box: CGRect) -> CGPath {
    let font = CTFontCreateWithName("Georgia-Bold" as CFString, 600, nil)
    let chars: [UniChar] = Array("\u{201C}\u{201D}".utf16)
    var glyphs = [CGGlyph](repeating: 0, count: chars.count)
    CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
    var advances = [CGSize](repeating: .zero, count: glyphs.count)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
    let path = CGMutablePath()
    var x: CGFloat = 0
    for (g, adv) in zip(glyphs, advances) {
        if let gp = CTFontCreatePathForGlyph(font, g, nil) {
            path.addPath(gp, transform: CGAffineTransform(translationX: x, y: 0))
        }
        x += adv.width + 110 // open space between the two marks
    }
    // Font space has y up; flip it and fit the drawn bounds into the box.
    let b = path.boundingBoxOfPath
    let scale = min(box.width / b.width, box.height / b.height)
    var t = CGAffineTransform.identity
        .translatedBy(x: box.midX, y: box.midY)
        .scaledBy(x: scale, y: -scale)
        .translatedBy(x: -b.midX, y: -b.midY)
    return path.copy(using: &t)!
}

func draw(_ ctx: CGContext) {
    // Work in top-left coordinates.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    let full = CGRect(x: 0, y: 0, width: size, height: size)

    // Background: violet → magenta → orange, like stage lights at sunset.
    ctx.drawLinearGradient(
        gradient([(0x5B21D6, 1, 0), (0xC026D3, 1, 0.42), (0xF43F5E, 1, 0.70), (0xFF8A1F, 1, 1)]),
        start: CGPoint(x: 120, y: 0), end: CGPoint(x: 900, y: size), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Spotlight glow from the top and a soft floor glow.
    ctx.drawRadialGradient(gradient([(0xFFFFFF, 0.34, 0), (0xFFFFFF, 0.0, 1)]),
        startCenter: CGPoint(x: 470, y: -40), startRadius: 0, endCenter: CGPoint(x: 470, y: -40), endRadius: 720, options: [])
    ctx.drawRadialGradient(gradient([(0xFFD166, 0.30, 0), (0xFFD166, 0.0, 1)]),
        startCenter: CGPoint(x: 512, y: 1060), startRadius: 0, endCenter: CGPoint(x: 512, y: 1060), endRadius: 520, options: [])
    // Gentle vignette for depth.
    ctx.drawRadialGradient(gradient([(0x000000, 0.0, 0.55), (0x1A0533, 0.22, 1)]),
        startCenter: CGPoint(x: 512, y: 470), startRadius: 0, endCenter: CGPoint(x: 512, y: 470), endRadius: 760, options: [.drawsAfterEndLocation])

    // Bubble with a soft drop shadow.
    let b = bubble()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 26), blur: 60, color: rgb(0x2A0845, 0.55))
    ctx.addPath(b)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(b)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFFFFF, 1, 0), (0xFFF4FA, 1, 0.6), (0xF6E8FF, 1, 1)]),
        start: CGPoint(x: 0, y: 214), end: CGPoint(x: 0, y: 846), options: [])
    ctx.restoreGState()

    // Quote marks filled with a warm gradient.
    let q = quotes(in: CGRect(x: 268, y: 338, width: 488, height: 236))
    ctx.saveGState()
    ctx.addPath(q)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFB703, 1, 0), (0xFF6A2B, 1, 0.5), (0xE0247A, 1, 1)]),
        start: CGPoint(x: 290, y: 330), end: CGPoint(x: 734, y: 580), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Sparkles: one large gold star at the bubble's corner, one small white one.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: rgb(0xFFF3B0, 0.9))
    ctx.addPath(sparkle(836, 214, 112))
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFFFFF, 1, 0), (0xFFE27A, 1, 0.55), (0xFFB703, 1, 1)]),
        start: CGPoint(x: 760, y: 110), end: CGPoint(x: 920, y: 320), options: [])
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: rgb(0xFFFFFF, 0.9))
    ctx.addPath(sparkle(918, 352, 40))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.addPath(sparkle(128, 168, 30))
    ctx.setFillColor(rgb(0xFFFFFF, 0.85))
    ctx.fillPath()
    ctx.restoreGState()
    _ = full
}

func render() -> Data {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let png = render()
for rel in ["SayItLike/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
            "SayItLike/Assets.xcassets/LogoMark.imageset/LogoMark.png"] {
    let url = root.appendingPathComponent(rel)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url)
    print("Wrote \(url.path)")
}
