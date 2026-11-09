import Combine
import SwiftUI

/// The games showcase: one page that shows the table's games one after another.
/// It moves on by itself; a tap moves on now (left third: back).
struct GamesPage: View {
    let games: [Game]
    static let interval: TimeInterval = 9

    @State private var index = 0
    @State private var shownAt = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let game = games[index]
        VStack(spacing: 0) {
            header
            GameCard(game: game)
                .id(game.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .frame(maxHeight: .infinity, alignment: .top)
            dots
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

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(games.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? games[i].color : Color.white.opacity(0.25))
                    .frame(width: i == index ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .padding(.top, 10)
    }

    private func step(_ by: Int) {
        withAnimation(.easeInOut(duration: 0.45)) {
            index = (index + by + games.count) % games.count
        }
        shownAt = Date()
    }
}

/// One game: its board, what it is, and what your phone does in it.
struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GameArt(game: game)
                .frame(height: 196)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(game.color.opacity(0.6), lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Chip(text: game.source.rawValue, color: game.color)
                    Chip(text: "\(game.players) players", color: .white.opacity(0.7), systemImage: "person.2.fill")
                }
                Text(game.name)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.top, 4)
                Text(game.tagline)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(game.color)
            }

            Text(game.description)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            phoneRow
        }
        .padding(.horizontal, 20)
    }

    private var phoneRow: some View {
        HStack(alignment: .center, spacing: 14) {
            if case .screenshot(let phone?) = game.art, let image = bundledImage(phone) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1))
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
                    .font(.system(size: 16, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

struct Chip: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text.uppercased())
        }
        .font(.system(size: 11, weight: .heavy))
        .tracking(1)
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().stroke(color.opacity(0.7), lineWidth: 1))
    }
}

/// The hero picture: a board screenshot, or for games without published
/// screenshots a picture drawn from their own art.
struct GameArt: View {
    let game: Game

    var body: some View {
        switch game.art {
        case .screenshot:
            if let image = bundledImage(game.id) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                game.color.opacity(0.3)
            }
        case .hexTiles(let tiles): HexTilesArt(tiles: tiles)
        case .imageRow(let images): ImageRowArt(images: images)
        case .marbleTrack(let title): MarbleTrackArt(title: title)
        }
    }
}

/// Hexagonal tiles in a honeycomb of three rows, the images repeated as needed.
struct HexTilesArt: View {
    let tiles: [String]

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = 78, h = w * 371 / 320
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.35, blue: 0.55), Color(red: 0.05, green: 0.20, blue: 0.35)],
                               startPoint: .top, endPoint: .bottom)
                ForEach(0..<12, id: \.self) { i in
                    let row = i / 4, col = i % 4
                    let x = geo.size.width / 2 + (CGFloat(col) - 1.5) * w + (row == 1 ? w / 4 : -w / 4)
                    let y = geo.size.height / 2 + CGFloat(row - 1) * h * 0.75
                    if !tiles.isEmpty, let image = bundledImage(tiles[i % tiles.count]) {
                        Image(uiImage: image).resizable().frame(width: w, height: h).position(x: x, y: y)
                    }
                }
            }
        }
    }
}

/// Pictures side by side on a grid floor.
struct ImageRowArt: View {
    let images: [String]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.22), Color(red: 0.30, green: 0.12, blue: 0.25)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var grid = Path()
                stride(from: 0, through: size.width, by: 28).forEach { x in
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0, through: size.height, by: 28).forEach { y in
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            HStack(spacing: -14) {
                ForEach(images, id: \.self) { name in
                    if let image = bundledImage(name) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(height: 150)
                    }
                }
            }
        }
    }
}

/// An oval track with four teams' marbles on their way, and a title.
struct MarbleTrackArt: View {
    let title: String
    private let colors: [Color] = [.yellow, .red, .blue, .green]

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.23, blue: 0.20)
            Canvas { context, size in
                let rect = CGRect(x: 30, y: 26, width: size.width - 60, height: size.height - 52)
                let track = Path(roundedRect: rect, cornerRadius: rect.height / 2)
                context.stroke(track, with: .color(Color(red: 0.19, green: 0.39, blue: 0.34)), lineWidth: 22)
                // Holes around the oval, a marble here and there.
                let n = 40
                for i in 0..<n {
                    let p = point(on: rect, at: CGFloat(i) / CGFloat(n))
                    let hole = Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
                    if i % 5 == 2 {
                        let color = colors[(i / 5) % colors.count]
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(color))
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 6, width: 5, height: 5)), with: .color(.white.opacity(0.6)))
                    } else {
                        context.fill(hole, with: .color(Color(red: 0.05, green: 0.16, blue: 0.14)))
                    }
                }
            }
            Text(title.uppercased())
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.35))
        }
    }

    /// A point on the stadium-shaped oval, `t` from 0 to 1.
    private func point(on rect: CGRect, at t: CGFloat) -> CGPoint {
        let r = rect.height / 2
        let straight = rect.width - 2 * r
        let total = 2 * straight + 2 * .pi * r
        var d = t * total
        if d < straight { return CGPoint(x: rect.minX + r + d, y: rect.minY) }
        d -= straight
        if d < .pi * r {
            let a = -CGFloat.pi / 2 + d / r
            return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.midY + r * sin(a))
        }
        d -= .pi * r
        if d < straight { return CGPoint(x: rect.maxX - r - d, y: rect.maxY) }
        d -= straight
        let a = CGFloat.pi / 2 + d / r
        return CGPoint(x: rect.minX + r + r * cos(a), y: rect.midY + r * sin(a))
    }
}
