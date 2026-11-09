import Combine
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Watches for touches anywhere in the app; after an hour without one it turns on
/// the energy saver, and the next touch turns it off again.
@MainActor
final class IdleMonitor: ObservableObject {
    @Published private(set) var isSaving = false

    /// One hour; "idle=<seconds>" as a launch argument shortens it for testing.
    let timeout: TimeInterval = ProcessInfo.processInfo.arguments
        .compactMap { $0.hasPrefix("idle=") ? TimeInterval($0.dropFirst(5)) : nil }.first ?? 3600

    private var lastTouch = Date()
    private var timer: Timer?
    private var recognizer: TouchRecognizer?

    func start() {
        installRecognizer()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: min(30, timeout / 4), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func touched() {
        #if DEBUG
        NSLog("GameCompanion: touch (energy saver %@)", isSaving ? "on" : "off")
        #endif
        lastTouch = Date()
        if isSaving { isSaving = false }
    }

    private func check() {
        if !isSaving, Date().timeIntervalSince(lastTouch) >= timeout { isSaving = true }
    }

    /// A recognizer on the window sees every touch without taking it from the views.
    private func installRecognizer() {
        guard recognizer == nil,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.windows.first }).first else {
            // The window may not be up yet on the first appearance; try again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.installRecognizer() }
            return
        }
        let recognizer = TouchRecognizer { [weak self] in self?.touched() }
        window.addGestureRecognizer(recognizer)
        #if DEBUG
        NSLog("GameCompanion: touch recognizer installed")
        #endif
        self.recognizer = recognizer
    }
}

/// Reports each touch-down and then steps aside, so no view loses its touches.
private final class TouchRecognizer: UIGestureRecognizer {
    private let onTouch: () -> Void

    init(onTouch: @escaping () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }
}

/// The energy saver: only the time, dim, on black (an OLED screen draws almost
/// nothing for black). The clock moves to a new spot every minute so it doesn't
/// burn in. Nothing else is drawn or animated meanwhile.
struct EnergySaverView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            GeometryReader { geo in
                let spot = Self.spot(for: context.date, in: geo.size)
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 54, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Color(white: 0.32))
                    .position(spot)
                    .animation(.easeInOut(duration: 2), value: spot)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    /// A pseudo-random place for this minute, inside the middle of the screen.
    private static func spot(for date: Date, in size: CGSize) -> CGPoint {
        let minute = Int(date.timeIntervalSince1970 / 60)
        func r(_ k: Double) -> Double {
            (sin(Double(minute) * 12.9898 + k * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
        }
        return CGPoint(x: size.width * (0.3 + 0.4 * r(1)), y: size.height * (0.2 + 0.6 * r(2)))
    }
}
