import Foundation
import os

/// Runs `operation`, returning its result, or nil as soon as `timeout` elapses — even if the operation
/// ignores cancellation (it is cancelled and `onTimeout` is called, but never awaited after the deadline).
func withTimeout<T: Sendable>(_ timeout: Duration,
                              operation: @escaping @Sendable () async -> T?,
                              onTimeout: @escaping @Sendable () -> Void = {}) async -> T? {
    let resumed = OSAllocatedUnfairLock(initialState: false)
    return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        /// Resumes once; the first caller wins.
        @Sendable func finish(_ value: T?) -> Bool {
            let first = resumed.withLock { done in
                defer { done = true }
                return !done
            }
            if first { continuation.resume(returning: value) }
            return first
        }
        let work = Task {
            let value = await operation()
            _ = finish(value)
        }
        Task {
            try? await Task.sleep(for: timeout)
            if finish(nil) {
                work.cancel()
                onTimeout()
            }
        }
    }
}
