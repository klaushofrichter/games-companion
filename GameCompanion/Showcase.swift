import Combine
import SwiftUI

/// The games showcase: one page that shows the table's games one after another,
/// each with an entrance, a slowly moving picture and a glowing backdrop in its
/// colour. It moves on by itself; a tap moves on now (left third: back).
struct GamesPage: View {
    let games: [Game]
    /// Room to leave around the content; the backdrop fills the whole screen.
    var insets = EdgeInsets()
    static let interval: TimeInterval = 9

    @State private var index = 0
    @State private var shownAt = Date()
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let game = games[index]
        ZStack {
            Backdrop(color: game.color)
                .id("backdrop-\(game.id)")
                .transition(.opacity)

            VStack(spacing: 0) {
                header
                // The outgoing game fades where it stands while the next one builds
                // up in the same place, so one game flows into the next.
                ZStack {
                    GameCard(game: game)
                        .id(game.id)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 1.04)).animation(.easeOut(duration: 0.35))))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                progress
            }
            .padding(insets)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(SpatialTapGesture().onEnded { tap in
            step(tap.location.x < 130 ? -1 : 1)
        })
        .onReceive(tick) { now in
            if now.timeIntervalSince(shownAt) >= Self.interval { step(1) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("GAME TABLE")
                .font(.system(size: 15, weight: .heavy))
                .tracking(3)
            Spacer()
            Text("\(games.count) games to play")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    /// One mark per game; the current one fills up until the next game comes.
    private var progress: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let fraction = min(1, context.date.timeIntervalSince(shownAt) / Self.interval)
            HStack(spacing: 7) {
                ForEach(games.indices, id: \.self) { i in
                    if i == index {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 34, height: 6)
                            .overlay(alignment: .leading) {
                                Capsule().fill(games[i].color)
                                    .frame(width: max(6, 34 * fraction))
                                    .shadow(color: games[i].color, radius: 4)
                            }
                    } else {
                        Circle().fill(Color.white.opacity(0.25)).frame(width: 6, height: 6)
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
        .padding(.top, 10)
    }

    private func step(_ by: Int) {
        withAnimation(.easeInOut(duration: 0.9)) {
            index = (index + by + games.count) % games.count
        }
        shownAt = Date()
    }
}

/// One game: its board, what it is, and what your phone does in it. The parts
/// come in one after another.
struct GameCard: View {
    let game: Game
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Hero(game: game)
                .rotation3DEffect(.degrees(appeared ? 0 : 35), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.7), value: appeared)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Chip(text: game.source.rawValue, color: game.color)
                    Chip(text: "\(game.players) players", color: .white.opacity(0.7), systemImage: "person.2.fill")
                }
                .entrance(appeared, delay: 0.25, x: -40)

                GlowingTitle(text: game.name, color: game.color)
                    .padding(.top, 4)
                    .entrance(appeared, delay: 0.35, y: 24)

                Text(game.tagline)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(game.color)
                    .entrance(appeared, delay: 0.45, y: 18)
            }

            phoneRow
                .padding(.top, 6)
                .entrance(appeared, delay: 0.6, y: 70)
        }
        .padding(.horizontal, 20)
        .onAppear { appeared = true }
    }

    private var phoneRow: some View {
        HStack(alignment: .center, spacing: 14) {
            if case .screenshot(let phone?) = game.art, let image = bundledImage(phone) {
                FloatingPhone(image: image, color: game.color)
            } else {
                Image(systemName: "iphone")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(game.color)
                    .frame(width: 44)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("ON YOUR PHONE")
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                Text(game.phone)
                    .font(.system(size: 18, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 170)   // the same height with or without a phone screenshot
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LinearGradient(colors: [game.color.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1))
        )
    }
}

private extension View {
    /// Slides and fades in once `shown` turns true, after `delay` seconds.
    func entrance(_ shown: Bool, delay: Double, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : x, y: shown ? 0 : y)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(delay), value: shown)
    }
}

/// The game's picture: it zooms in slowly while the game is shown, a band of light
/// sweeps across it once, and its frame glows in the game's colour.
struct Hero: View {
    let game: Game
    @State private var zoomed = false
    @State private var swept = false

    var body: some View {
        GeometryReader { geo in
            GameArt(game: game)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoomed ? 1.14 : 1.0, anchor: zoomAnchor)
                .overlay(
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.35)
                        .rotationEffect(.degrees(18))
                        .offset(x: swept ? geo.size.width * 1.2 : -geo.size.width * 1.2)
                        .blendMode(.screen)
                )
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(LinearGradient(colors: [game.color, game.color.opacity(0.2), game.color],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
        .modifier(Pulse(color: game.color))
        .onAppear {
            withAnimation(.linear(duration: GamesPage.interval + 1)) { zoomed = true }
            withAnimation(.easeInOut(duration: 1.1).delay(0.6)) { swept = true }
        }
    }

    /// Each game zooms toward a different spot, so they don't all move alike.
    private var zoomAnchor: UnitPoint {
        let anchors: [UnitPoint] = [.center, .topLeading, .bottomTrailing, .topTrailing, .bottomLeading]
        return anchors[abs(game.id.hashValue) % anchors.count]
    }
}

/// A soft glow around the view, breathing slowly.
struct Pulse: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content.shadow(color: color.opacity(0.35 + 0.25 * sin(t * 2)), radius: 14 + 6 * sin(t * 2))
        }
    }
}

/// The game's name in white fading into its colour, with a glow.
struct GlowingTitle: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 40, weight: .black, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(LinearGradient(colors: [.white, .white, color], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: color.opacity(0.7), radius: 12)
    }
}

/// The phone screenshot, floating and turning a little.
struct FloatingPhone: View {
    let image: UIImage
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: color.opacity(0.5), radius: 10, y: 6)
                .rotation3DEffect(.degrees(8 * sin(t * 0.9)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .offset(y: 4 * sin(t * 1.3))
        }
    }
}

/// Behind the showcase: blobs of the game's colour drifting slowly, and sparks rising.
struct Backdrop: View {
    let color: Color

    private struct Spark { let x, speed, size, phase: Double }
    private let sparks: [Spark] = (0..<36).map { i in
        // Fixed pseudo-random values, so the sparks don't jump when the view is rebuilt.
        func r(_ k: Double) -> Double { (sin(Double(i) * 12.9898 + k * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude }
        return Spark(x: r(1), speed: 0.025 + 0.05 * r(2), size: 1.5 + 3 * r(3), phase: r(4))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Three slow blobs.
                let blobs: [(Double, Double, Double, Double)] = [(0.3, 0.25, 0.11, 0.0), (0.75, 0.55, 0.08, 2.0), (0.4, 0.85, 0.06, 4.0)]
                for (bx, by, speed, phase) in blobs {
                    let center = CGPoint(x: size.width * (bx + 0.18 * sin(t * speed + phase)),
                                         y: size.height * (by + 0.10 * cos(t * speed * 1.3 + phase)))
                    let radius = size.width * 0.75
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                             with: .radialGradient(Gradient(colors: [color.opacity(0.28), color.opacity(0)]),
                                                   center: center, startRadius: 0, endRadius: radius))
                }
                // Sparks rising and twinkling.
                for s in sparks {
                    let y = (1 - (s.phase + t * s.speed).truncatingRemainder(dividingBy: 1)) * size.height
                    let x = size.width * s.x + 10 * sin(t * 0.7 + s.phase * 6)
                    let alpha = 0.25 + 0.5 * (0.5 + 0.5 * sin(t * 3 + s.phase * 20))
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s.size, height: s.size)),
                             with: .color(color.opacity(alpha)))
                }
            }
        }
    }
}
