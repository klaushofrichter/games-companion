import SwiftUI

/// A quiet page for when nobody needs the phone: slow light that doesn't pull the
/// eye from the board. Two looks, an aurora and soft waves; a tap switches.
struct ScreensaverPage: View {
    enum Look: String { case aurora, waves }
    @AppStorage("screensaverLook") private var look = Look.aurora

    var body: some View {
        ZStack {
            switch look {
            case .aurora: AuroraView().transition(.opacity)
            case .waves: WavesView().transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .opacity(0.75)   // muted on purpose
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 1.5)) { look = look == .aurora ? .waves : .aurora }
        }
    }
}

/// Fixed pseudo-random numbers, so drawings don't jump between frames.
private func noise(_ i: Int, _ k: Double) -> Double {
    (sin(Double(i) * 12.9898 + k * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
}

/// Curtains of green, teal and violet light swaying over a starry night.
struct AuroraView: View {
    private struct Curtain { let color: Color; let base, reach, freq, speed, phase: Double }
    private let curtains = [
        Curtain(color: Color(red: 0.25, green: 0.95, blue: 0.55), base: 0.30, reach: 0.30, freq: 1.3, speed: 0.050, phase: 0),
        Curtain(color: Color(red: 0.15, green: 0.75, blue: 0.85), base: 0.42, reach: 0.22, freq: 0.9, speed: 0.035, phase: 2.1),
        Curtain(color: Color(red: 0.60, green: 0.35, blue: 0.95), base: 0.22, reach: 0.18, freq: 1.7, speed: 0.028, phase: 4.3),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.10), .black]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                // Stars, twinkling slowly.
                for i in 0..<70 {
                    let p = CGPoint(x: noise(i, 1) * size.width, y: noise(i, 2) * size.height)
                    let a = 0.15 + 0.35 * (0.5 + 0.5 * sin(t * (0.3 + noise(i, 3)) + noise(i, 4) * 10))
                    let r = 0.6 + 1.2 * noise(i, 5)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: r, height: r)), with: .color(.white.opacity(a)))
                }
                // Curtains: thin vertical streaks whose top edge waves, brighter here and there.
                ctx.blendMode = .plusLighter
                let step: CGFloat = 4
                for c in curtains {
                    var x: CGFloat = 0
                    var column = 0
                    while x < size.width {
                        let u = Double(x / size.width)
                        let sway: Double = 0.07 * sin(u * .pi * 2 * c.freq + t * c.speed * 6 + c.phase)
                        let ripple: Double = 0.03 * sin(u * .pi * 7 + t * c.speed * 11)
                        let top = size.height * CGFloat(c.base + sway + ripple)
                        let stretch: Double = 0.7 + 0.3 * sin(u * .pi * 3 + t * c.speed * 4 + c.phase)
                        let height = size.height * CGFloat(c.reach * stretch)
                        let shimmer: Double = 0.5 + 0.5 * sin(u * .pi * 4.6 - t * c.speed * 9 + c.phase + noise(column, 6))
                        let glow: Double = 0.35 + 0.65 * shimmer * shimmer
                        let rect = CGRect(x: x, y: top, width: step + 1, height: height)
                        ctx.fill(Path(rect), with: .linearGradient(
                            Gradient(stops: [.init(color: c.color.opacity(0), location: 0),
                                             .init(color: c.color.opacity(0.45 * glow), location: 0.25),
                                             .init(color: c.color.opacity(0), location: 1)]),
                            startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: top + height)))
                        x += step
                        column += 1
                    }
                }
            }
        }
    }
}

/// Soft ribbons of thin lines rolling over a gradient whose colour changes slowly
/// through the hours.
struct WavesView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // A full turn of the colour wheel every 20 minutes.
            let hue = (t / 1200).truncatingRemainder(dividingBy: 1)
            Canvas { ctx, size in
                let top = Color(hue: hue, saturation: 0.65, brightness: 0.35)
                let bottom = Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.10)
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: .zero,
                                               endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
                ctx.blendMode = .plusLighter
                // Two ribbons, each a bundle of lines with slightly shifted phases.
                for (ribbon, centre) in [(0, 0.52), (1, 0.62)] {
                    let speed = ribbon == 0 ? 0.12 : 0.08
                    // A wide soft band under the lines.
                    var band = Path()
                    let samples = 60
                    for s in 0...samples {
                        let x = size.width * CGFloat(s) / CGFloat(samples)
                        let y = wave(x / size.width, t: t, speed: speed, offset: 0, ribbon: ribbon) * size.height * 0.1 + size.height * centre
                        s == 0 ? band.move(to: CGPoint(x: x, y: y - 30)) : band.addLine(to: CGPoint(x: x, y: y - 30))
                    }
                    for s in stride(from: samples, through: 0, by: -1) {
                        let x = size.width * CGFloat(s) / CGFloat(samples)
                        let y = wave(x / size.width, t: t, speed: speed, offset: 0.6, ribbon: ribbon) * size.height * 0.1 + size.height * centre
                        band.addLine(to: CGPoint(x: x, y: y + 30))
                    }
                    band.closeSubpath()
                    ctx.fill(band, with: .color(.white.opacity(0.05)))
                    for line in 0..<9 {
                        var path = Path()
                        for s in 0...samples {
                            let x = size.width * CGFloat(s) / CGFloat(samples)
                            let y = wave(x / size.width, t: t, speed: speed, offset: Double(line) * 0.09, ribbon: ribbon)
                                * size.height * 0.1 + size.height * centre + CGFloat(line - 4) * 5
                            s == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                        }
                        ctx.stroke(path, with: .color(.white.opacity(0.10 + 0.04 * Double(line % 3))), lineWidth: 0.8)
                    }
                }
                // A few motes drifting up.
                for i in 0..<24 {
                    let y = (1 - (noise(i, 1) + t * (0.004 + 0.006 * noise(i, 2))).truncatingRemainder(dividingBy: 1)) * size.height
                    let x = noise(i, 3) * size.width + 12 * sin(t * 0.2 + noise(i, 4) * 6)
                    let r = 1 + 2 * noise(i, 5)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.18)))
                }
            }
        }
    }

    private func wave(_ u: CGFloat, t: Double, speed: Double, offset: Double, ribbon: Int) -> CGFloat {
        let u = Double(u)
        let f = ribbon == 0 ? 1.0 : 1.4
        return CGFloat(sin(u * .pi * 2 * f + t * speed + offset) * 0.8
                       + sin(u * .pi * 3.3 * f - t * speed * 0.7 + offset * 1.7) * 0.4)
    }
}
