import AVFoundation
import Combine
import UIKit

/// Estimates room brightness from time to time with the front camera (iOS has no
/// public ambient light sensor API) and maps it to a level from 0 (dark room) to
/// 1 (bright room). The level sets the screen brightness and, in the dark, how much
/// the app dims itself below what the screen can do. Ported from iPadDash.
///
/// Each sample runs the camera without preview for about a second so auto-exposure
/// settles, reads the exposure the camera chose (duration, ISO, aperture) and stops
/// again. No frames are read or kept. Lying flat, the front camera sees the ceiling.
@MainActor
final class AmbientLight: ObservableObject {
    /// 0 = dark room ... 1 = bright room.
    @Published private(set) var level: Double = 1
    @Published private(set) var lux: Double?

    static let interval: TimeInterval = 300

    // Lux range mapped onto 0...1 on a log scale: ~3 lux (night light) to ~300 lux (lit room).
    private let darkLux = 3.0, brightLux = 300.0
    private let sampler = Sampler()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        #if DEBUG
        // Simulators have no camera: COMPANION_LUX=<lux> fakes a reading.
        if let fake = ProcessInfo.processInfo.environment["COMPANION_LUX"].flatMap(Double.init) {
            record(lux: fake)
            return
        }
        #endif
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sampler.measure { [weak self] lux in
                Task { @MainActor in if let lux { self?.record(lux: lux) } }
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in if granted { self?.sample() } }
            }
        default:
            break   // no camera access: full brightness, left to iOS
        }
    }

    private func record(lux: Double) {
        self.lux = lux
        let t = (log10(max(lux, 0.01)) - log10(darkLux)) / (log10(brightLux) - log10(darkLux))
        let newLevel = min(max(t, 0), 1)
        // Ignore small changes so the screen doesn't flicker between samples.
        guard abs(newLevel - level) >= 0.04 else { return }
        level = newLevel
        UIScreen.main.brightness = CGFloat(0.05 + 0.85 * level)
    }

    /// How dark to veil the app on top of the screen brightness: nothing in a lit
    /// room, up to half in a dark one.
    var veil: Double { 0.5 * (1 - level) }
}

/// The camera part, on its own queue.
private final class Sampler: @unchecked Sendable {
    private let queue = DispatchQueue(label: "AmbientLight")
    private var session: AVCaptureSession?
    private var camera: AVCaptureDevice?
    private var busy = false

    func measure(_ done: @escaping @Sendable (Double?) -> Void) {
        queue.async { self.run(done) }
    }

    private func run(_ done: @escaping @Sendable (Double?) -> Void) {
        guard !busy else { return }
        if session == nil {
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return done(nil) }
            let session = AVCaptureSession()
            session.sessionPreset = .low
            // An output keeps the camera streaming so auto-exposure runs; frames are discarded.
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            guard session.canAddInput(input), session.canAddOutput(output) else { return done(nil) }
            session.addInput(input)
            session.addOutput(output)
            self.session = session
            self.camera = camera
        }
        guard let session, let camera else { return done(nil) }
        busy = true
        session.startRunning()
        queue.asyncAfter(deadline: .now() + 1.2) {
            let exposure = camera.exposureDuration
            let duration = exposure.timescale > 0 ? Double(exposure.value) / Double(exposure.timescale) : 0
            let iso = Double(camera.iso)
            let aperture = Double(camera.lensAperture)
            session.stopRunning()
            self.busy = false
            guard duration > 0, iso > 0, aperture > 0 else { return done(nil) }
            // Exposure value at ISO 100, then illuminance (incident-light constant ~250).
            let ev100 = log2(aperture * aperture / duration) - log2(iso / 100)
            done(2.5 * pow(2, ev100))
        }
    }
}
