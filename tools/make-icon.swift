// Draws the app icon: a game board with die pips and a phone beside it, over a
// dark aurora sky. Run: swift tools/make-icon.swift GameCompanion/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, a])! }
func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// Core Graphics' origin is bottom left; flip so y grows downward like the app.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Sky: deep indigo to dark teal, with aurora glows.
ctx.drawLinearGradient(gradient([rgb(0.09, 0.07, 0.26), rgb(0.02, 0.17, 0.24)]),
                       start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
for (x, y, r, color) in [(0.25, 0.20, 0.55, rgb(0.25, 0.95, 0.55, 0.35)),
                         (0.85, 0.30, 0.45, rgb(0.60, 0.35, 0.95, 0.35)),
                         (0.60, 0.95, 0.50, rgb(0.15, 0.75, 0.85, 0.30))] {
    let c = CGPoint(x: size * x, y: size * y)
    ctx.drawRadialGradient(gradient([color, rgb(0, 0, 0, 0)]), startCenter: c, startRadius: 0,
                           endCenter: c, endRadius: size * r, options: [])
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// The board: green felt, tilted, with a five on it.
ctx.saveGState()
ctx.translateBy(x: size * 0.40, y: size * 0.43)
ctx.rotate(by: -0.14)
let board = CGRect(x: -270, y: -270, width: 540, height: 540)
ctx.setShadow(offset: CGSize(width: 0, height: 24), blur: 50, color: rgb(0, 0, 0, 0.55))
ctx.addPath(rounded(board, 90))
ctx.setFillColor(rgb(0.08, 0.42, 0.28))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.saveGState()
ctx.addPath(rounded(board, 90))
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0.16, 0.62, 0.40), rgb(0.05, 0.30, 0.20)]),
                       start: CGPoint(x: -270, y: -270), end: CGPoint(x: 270, y: 270), options: [])
ctx.restoreGState()
ctx.addPath(rounded(board.insetBy(dx: 14, dy: 14), 78))
ctx.setStrokeColor(rgb(1, 1, 1, 0.25))
ctx.setLineWidth(6)
ctx.strokePath()
for (px, py) in [(-1.0, -1.0), (1.0, -1.0), (0.0, 0.0), (-1.0, 1.0), (1.0, 1.0)] {
    let c = CGPoint(x: px * 140, y: py * 140)
    ctx.setShadow(offset: .zero, blur: 30, color: rgb(1, 1, 1, 0.6))
    ctx.setFillColor(rgb(0.97, 0.97, 0.94))
    ctx.fillEllipse(in: CGRect(x: c.x - 50, y: c.y - 50, width: 100, height: 100))
}
ctx.restoreGState()

// The phone, leaning in at the lower right, with a glowing card on its screen.
ctx.saveGState()
ctx.translateBy(x: size * 0.75, y: size * 0.70)
ctx.rotate(by: 0.20)
let body = CGRect(x: -125, y: -225, width: 250, height: 450)
ctx.setShadow(offset: CGSize(width: 0, height: 20), blur: 40, color: rgb(0, 0, 0, 0.6))
ctx.addPath(rounded(body, 48))
ctx.setFillColor(rgb(0.07, 0.07, 0.09))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.addPath(rounded(body, 48))
ctx.setStrokeColor(rgb(0.85, 0.87, 0.92))
ctx.setLineWidth(10)
ctx.strokePath()
let screen = body.insetBy(dx: 20, dy: 20)
ctx.saveGState()
ctx.addPath(rounded(screen, 32))
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0.95, 0.55, 0.20), rgb(0.80, 0.20, 0.35)]),
                       start: CGPoint(x: 0, y: screen.minY), end: CGPoint(x: 0, y: screen.maxY), options: [])
ctx.restoreGState()
let card = CGRect(x: -65, y: -100, width: 130, height: 185)
ctx.setShadow(offset: .zero, blur: 28, color: rgb(1, 0.9, 0.6, 0.9))
ctx.addPath(rounded(card, 16))
ctx.setFillColor(rgb(1, 0.98, 0.95))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)
// A heart on the card.
let heart = CGMutablePath()
heart.move(to: CGPoint(x: 0, y: 30))
heart.addCurve(to: CGPoint(x: -40, y: -22), control1: CGPoint(x: -20, y: 10), control2: CGPoint(x: -42, y: -2))
heart.addArc(center: CGPoint(x: -20, y: -24), radius: 20, startAngle: .pi, endAngle: 0, clockwise: false)
heart.addArc(center: CGPoint(x: 20, y: -24), radius: 20, startAngle: .pi, endAngle: 0, clockwise: false)
heart.addCurve(to: CGPoint(x: 0, y: 30), control1: CGPoint(x: 42, y: -2), control2: CGPoint(x: 20, y: 10))
ctx.addPath(heart)
ctx.setFillColor(rgb(0.85, 0.15, 0.25))
ctx.fillPath()
ctx.restoreGState()

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
