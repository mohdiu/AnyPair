import CoreLocation
import Foundation

/// A light location session so iOS keeps AnyPair running while the user is in
/// Settings › Developer Mode (from AnyGPS).
final class LocationKeepAlive: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationWaiter: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    /// Shows the location prompt (if not answered yet) and waits for the answer.
    @MainActor
    func requestAuthorization() async {
        guard manager.authorizationStatus == .notDetermined, authorizationWaiter == nil else { return }
        await withCheckedContinuation { continuation in
            authorizationWaiter = continuation
            manager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined, let waiter = authorizationWaiter else { return }
        authorizationWaiter = nil
        waiter.resume()
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
