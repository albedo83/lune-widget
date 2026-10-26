import CoreLocation

/// Waits for an authorization decision, bounded by a timeout; the continuation is resumed exactly once.
@MainActor
final class AuthorizationWaiter {
    private var continuation: CheckedContinuation<CLAuthorizationStatus?, Never>?

    /// Runs `start`, then returns the first decided status delivered, or nil after `timeout`.
    func wait(timeout: Duration, start: () -> Void) async -> CLAuthorizationStatus? {
        let timer = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.finish(nil)
        }
        let result = await withCheckedContinuation { (c: CheckedContinuation<CLAuthorizationStatus?, Never>) in
            continuation = c
            start()
        }
        timer.cancel()
        return result
    }

    func deliver(_ status: CLAuthorizationStatus) {
        guard status != .notDetermined else { return }
        finish(status)
    }

    private func finish(_ status: CLAuthorizationStatus?) {
        guard let c = continuation else { return }
        continuation = nil
        c.resume(returning: status)
    }
}

/// Asks for When-In-Use location access and reports whether it was granted.
@MainActor
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    static let promptTimeout: Duration = .seconds(60)

    private let manager = CLLocationManager()
    private let waiter = AuthorizationWaiter()

    override init() {
        super.init()
        manager.delegate = self
    }

    var isUndetermined: Bool { manager.authorizationStatus == .notDetermined }

    /// True when access is granted, prompting first when still undetermined. False when denied, restricted,
    /// or when no decision arrives within `promptTimeout`.
    func ensureAuthorized() async -> Bool {
        if manager.authorizationStatus == .notDetermined {
            _ = await waiter.wait(timeout: Self.promptTimeout) { manager.requestWhenInUseAuthorization() }
        }
        return CurrentPlaceLocator.isAuthorized(manager.authorizationStatus)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in waiter.deliver(status) }
    }
}
