import Combine
import CoreLocation
import SwiftUI

/// Current weather where the phone is, from Open-Meteo (free, no key). The
/// location comes from Location Services (Wi-Fi positioning is plenty) and is
/// remembered, so the weather still loads when a fresh fix doesn't come.
@MainActor
final class Weather: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Now {
        let temperature: Double   // °C
        let high: Double
        let low: Double
        let code: Int             // WMO weather code
        let isDay: Bool
        let place: String?
        let time: Date
    }

    @Published private(set) var now: Now?
    @Published private(set) var problem: String?

    private let manager = CLLocationManager()
    private var place: String?
    private var refreshTask: Task<Void, Never>?
    private static let latKey = "weatherLatitude", lonKey = "weatherLongitude"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Fetches now and every 15 minutes after that.
    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.locate()
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            }
        }
    }

    private func locate() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: load(savedLocation)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .notDetermined: break
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            default: self.load(self.savedLocation)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            if let location { self.savedLocation = location }
            self.load(self.savedLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.load(self.savedLocation) }
    }

    private var savedLocation: CLLocation? {
        get {
            let d = UserDefaults.standard
            guard d.object(forKey: Self.latKey) != nil else { return nil }
            return CLLocation(latitude: d.double(forKey: Self.latKey), longitude: d.double(forKey: Self.lonKey))
        }
        set {
            UserDefaults.standard.set(newValue?.coordinate.latitude, forKey: Self.latKey)
            UserDefaults.standard.set(newValue?.coordinate.longitude, forKey: Self.lonKey)
        }
    }

    private func load(_ location: CLLocation?) {
        guard let location else {
            problem = manager.authorizationStatus == .denied ? "Location access is off" : "Location unknown"
            return
        }
        Task {
            if place == nil {
                place = try? await CLGeocoder().reverseGeocodeLocation(location).first?.locality
            }
            let c = location.coordinate
            let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(c.latitude)&longitude=\(c.longitude)"
                + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min"
                + "&forecast_days=1&timezone=auto")!
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let r = try JSONDecoder().decode(Response.self, from: data)
                now = Now(temperature: r.current.temperature_2m, high: r.daily.temperature_2m_max.first ?? r.current.temperature_2m,
                          low: r.daily.temperature_2m_min.first ?? r.current.temperature_2m,
                          code: r.current.weather_code, isDay: r.current.is_day == 1, place: place, time: Date())
                problem = nil
            } catch {
                problem = "Weather unavailable"
            }
        }
    }

    private struct Response: Decodable {
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let is_day: Int }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let current: Current
        let daily: Daily
    }
}

extension Weather.Now {
    /// SF Symbol and words for the WMO code.
    var condition: (symbol: String, text: String) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
        case 1, 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", code == 1 ? "Mostly clear" : "Partly cloudy")
        case 3: return ("cloud.fill", "Overcast")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51...57: return ("cloud.drizzle.fill", "Drizzle")
        case 61...67, 80...82: return ("cloud.rain.fill", "Rain")
        case 71...77, 85, 86: return ("cloud.snow.fill", "Snow")
        case 95...99: return ("cloud.bolt.rain.fill", "Thunderstorm")
        default: return ("cloud.fill", "Cloudy")
        }
    }
}

/// "72°" in the phone's units (°F in the US).
func degrees(_ celsius: Double) -> String {
    let m = Measurement(value: celsius, unit: UnitTemperature.celsius)
    let f = MeasurementFormatter()
    f.numberFormatter.maximumFractionDigits = 0
    f.unitStyle = .short
    return f.string(from: m)
}
