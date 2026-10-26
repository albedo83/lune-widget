import CoreLocation

/// Asks for When-In-Use location access and reports whether it was granted.
@MainActor
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    /// Current status, prompting first when it is still undetermined. Returns true when access is granted.
    func ensureAuthorized() async -> Bool {
        if manager.authorizationStatus == .notDetermined {
            _ = await withCheckedContinuation { (c: CheckedContinuation<CLAuthorizationStatus, Never>) in
                continuation = c
                manager.requestWhenInUseAuthorization()
            }
        }
        return CurrentPlaceLocator.isAuthorized(manager.authorizationStatus)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined, let c = continuation else { return }
            continuation = nil
            c.resume(returning: status)
        }
    }
}
