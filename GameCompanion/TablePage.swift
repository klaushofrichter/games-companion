import Combine
import SwiftUI

/// The table's status: what's being played, the time, a game timer and the weather.
struct TablePage: View {
    @ObservedObject var weather: Weather
    @StateObject private var timer = GameTimer()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 18) {
                nowPlaying
                clock(context.date)
                timerCard(context.date)
                weatherCard
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Now playing

    /// Nothing is connected to the table yet, so this says so. When the table PC
    /// can tell the phone, it shows the game, the round and the players here.
    private var nowPlaying: some View {
        HStack(spacing: 12) {
            Image(systemName: "dice.fill")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.45))
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 12, weight: .heavy)).tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                Text("No game running")
                    .font(.system(size: 20, weight: .bold))
                Text("Pick a game on the table")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .card()
    }

    // MARK: - Clock

    private func clock(_ date: Date) -> some View {
        VStack(spacing: 0) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 76, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 4)
    }

    // MARK: - Game timer

    private func timerCard(_ date: Date) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("GAME TIMER")
                    .font(.system(size: 12, weight: .heavy)).tracking(1.5)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            Text(GameTimer.text(timer.elapsed(at: date)))
                .font(.system(size: 54, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(timer.isRunning ? .white : .white.opacity(0.6))
            HStack(spacing: 12) {
                Button { timer.toggle() } label: {
                    Label(timer.isRunning ? "Pause" : (timer.elapsed(at: date) > 0 ? "Resume" : "Start"),
                          systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(timer.isRunning ? Color.orange.opacity(0.85) : Color.green.opacity(0.8)))
                }
                Button { timer.reset() } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .disabled(timer.elapsed(at: date) == 0)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
        }
        .card()
    }

    // MARK: - Weather

    private var weatherCard: some View {
        HStack(spacing: 16) {
            if let now = weather.now {
                Image(systemName: now.condition.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 46))
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(degrees(now.temperature))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("\(now.condition.text) · H \(degrees(now.high))  L \(degrees(now.low))")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                    if let place = now.place {
                        Text(place)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            } else {
                Image(systemName: "cloud.sun")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 60)
                Text(weather.problem ?? "Loading weather…")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .card()
    }
}

/// A stopwatch for the game; it keeps time across restarts of the app.
@MainActor
final class GameTimer: ObservableObject {
    @Published private(set) var startedAt: Date?
    @Published private(set) var banked: TimeInterval = 0

    private let d = UserDefaults.standard

    init() {
        startedAt = d.object(forKey: "timerStartedAt") as? Date
        banked = d.double(forKey: "timerBanked")
    }

    var isRunning: Bool { startedAt != nil }

    func elapsed(at date: Date) -> TimeInterval {
        banked + (startedAt.map { date.timeIntervalSince($0) } ?? 0)
    }

    func toggle() {
        if let startedAt {
            banked += Date().timeIntervalSince(startedAt)
            self.startedAt = nil
        } else {
            startedAt = Date()
        }
        save()
    }

    func reset() {
        startedAt = isRunning ? Date() : nil
        banked = 0
        save()
    }

    private func save() {
        d.set(startedAt, forKey: "timerStartedAt")
        d.set(banked, forKey: "timerBanked")
    }

    static func text(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}
