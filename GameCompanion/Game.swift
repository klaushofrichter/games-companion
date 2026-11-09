import SwiftUI

/// One game the table can play, as the companion advertises it.
///
/// The public games are listed here. Games that must stay out of this public
/// repository come from `Private/house-games.json` (with their pictures in the
/// same folder), which is git-ignored and bundled when it exists. Later the
/// table PC can send its own list; the bundled one stays the fallback.
struct Game: Identifiable {
    enum Source: String {
        case builtIn = "Built in"
        case extraGames = "Extra games"
        case house = "House game"
    }

    /// How the game's hero picture is made.
    enum Art {
        /// A board screenshot, `<id>.webp`, and an optional phone screenshot.
        case screenshot(phone: String?)
        /// Hexagonal tiles in a honeycomb (image files, repeated as needed).
        case hexTiles([String])
        /// Pictures side by side on a grid floor.
        case imageRow([String])
        /// An oval track with coloured marbles and a title.
        case marbleTrack(String)
    }

    let id: String
    let name: String
    let players: String
    let tagline: String
    let description: String
    let phone: String
    let source: Source
    let color: Color
    let art: Art
}

extension Game {
    static let publicGames: [Game] = [
        Game(id: "holdem", name: "Hold'em", players: "2–8",
             tagline: "Fixed-limit Texas Hold'em",
             description: "The board shows the shared cards and the pot. AI players in two styles, side pots and awards at the end.",
             phone: "Your two cards stay hidden on your phone.",
             source: .builtIn, color: Color(red: 0.13, green: 0.55, blue: 0.33), art: .screenshot(phone: "holdem-phone")),
        Game(id: "backgammon", name: "Backgammon", players: "2",
             tagline: "The classic race for two",
             description: "Roll, move your checkers by tap or drag, hit blots and bear off first. Matches with the doubling cube; AI up to a neural-network engine.",
             phone: "Played on the board; the phone holds your seat.",
             source: .extraGames, color: Color(red: 0.62, green: 0.32, blue: 0.18), art: .screenshot(phone: nil)),
        Game(id: "liars-dice", name: "Liar's Dice", players: "2–6",
             tagline: "Bid, bluff, call the lie",
             description: "Bid how many dice of a face are on the table, or call the last bid a lie. Lose a die when you're wrong; the last player with dice wins.",
             phone: "Your dice are rolled in secret under your phone.",
             source: .extraGames, color: Color(red: 0.75, green: 0.20, blue: 0.20), art: .screenshot(phone: "liars-dice-phone")),
        Game(id: "chess", name: "Chess", players: "2",
             tagline: "Tap a piece, tap its square",
             description: "Clocks from bullet to classical, or none. AI from 400 to 2200 Elo, or Stockfish and the Lichess cloud.",
             phone: "Played on the board; the phone holds your seat.",
             source: .extraGames, color: Color(red: 0.55, green: 0.55, blue: 0.60), art: .screenshot(phone: nil)),
        Game(id: "mexican-train", name: "Mexican Train", players: "2–8",
             tagline: "Dominoes up to double twelve",
             description: "Grow your own train from the hub, or the Mexican train everyone shares. Animated backgrounds, its own music and sound.",
             phone: "Your tiles stay on your phone; two taps to play.",
             source: .extraGames, color: Color(red: 0.30, green: 0.45, blue: 0.85), art: .screenshot(phone: nil)),
        Game(id: "last-card", name: "Last Card", players: "2–8",
             tagline: "Match the colour or the number",
             description: "Skips, reverses, draw cards and wilds. Shout your last card and be first to 200 points.",
             phone: "Push a card off the top of your phone onto the pile.",
             source: .extraGames, color: Color(red: 0.90, green: 0.40, blue: 0.15), art: .screenshot(phone: "last-card-sling-phone")),
        Game(id: "roulette", name: "Roulette", players: "1–6",
             tagline: "European single-zero roulette",
             description: "Everyone bets at once, then the wheel spins. Three AI styles. Points only, never money.",
             phone: "Place your bets from your phone.",
             source: .builtIn, color: Color(red: 0.70, green: 0.15, blue: 0.20), art: .screenshot(phone: "roulette-phone")),
        Game(id: "pachisi", name: "Pachisi", players: "2–4",
             tagline: "Race your tokens home",
             description: "Roll a 6 to leave the start, touch a token to move it, land on someone to send them back.",
             phone: "Played on the board; the phone holds your seat.",
             source: .builtIn, color: Color(red: 0.85, green: 0.65, blue: 0.10), art: .screenshot(phone: nil)),
        Game(id: "coin-flip", name: "Coin Flip", players: "1–8",
             tagline: "Heads or tails?",
             description: "Everyone guesses, then the coin flips. Most correct guesses wins. The quickest game at the table.",
             phone: "Guess from your phone.",
             source: .builtIn, color: Color(red: 0.75, green: 0.60, blue: 0.25), art: .screenshot(phone: "coin-flip-phone")),
    ]

    /// Public and house games mixed, so the house games don't all come at the end.
    static let catalog: [Game] = {
        let house = houseGames()
        guard !house.isEmpty else { return publicGames }
        var all: [Game] = []
        let step = max(1, publicGames.count / house.count)
        var h = house.makeIterator()
        for (i, game) in publicGames.enumerated() {
            all.append(game)
            if (i + 1) % step == 0, let next = h.next() { all.append(next) }
        }
        while let next = h.next() { all.append(next) }
        return all
    }()

    /// `Private/house-games.json`, if it was bundled.
    private static func houseGames() -> [Game] {
        guard let url = Bundle.main.url(forResource: "house-games", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data).map(\.game)
        } catch {
            NSLog("GameCompanion: house-games.json: %@", String(describing: error))
            return []
        }
    }

    private struct Entry: Decodable {
        struct ArtEntry: Decodable {
            let kind: String
            let images: [String]?
            let title: String?
        }
        let id, name, players, tagline, description, phone: String
        let color: [Double]
        let art: ArtEntry

        var game: Game {
            let art: Art
            switch self.art.kind {
            case "hexTiles": art = .hexTiles(self.art.images ?? [])
            case "imageRow": art = .imageRow(self.art.images ?? [])
            default: art = .marbleTrack(self.art.title ?? name)
            }
            let c = color + [0, 0, 0]
            return Game(id: id, name: name, players: players, tagline: tagline, description: description, phone: phone,
                        source: .house, color: Color(red: c[0], green: c[1], blue: c[2]), art: art)
        }
    }
}

/// Images bundled from Games/ or Private/, loaded by file name (they aren't in the asset catalog).
func bundledImage(_ name: String, _ ext: String? = nil) -> UIImage? {
    let file = name as NSString
    let ext = ext ?? (file.pathExtension.isEmpty ? "webp" : file.pathExtension)
    guard let url = Bundle.main.url(forResource: file.deletingPathExtension, withExtension: ext) else { return nil }
    return UIImage(contentsOfFile: url.path)
}
