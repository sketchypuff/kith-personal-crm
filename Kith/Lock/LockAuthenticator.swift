import Foundation
import LocalAuthentication

/// The one wrapper around `LAContext`. Used both when enabling the lock in
/// Settings (authenticate once before the switch commits) and by the
/// foreground gate.
struct LockAuthenticator {

    /// Probes a fresh context; cheap enough to call on appear and on foreground.
    func availability() -> LockAvailability {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return .passcodeNotSet
        }
        // Populates `biometryType`; a false result just means passcode only
        // (not enrolled, or biometry locked out — the passcode still works).
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcodeOnly
        }
    }

    /// Biometry with passcode fallback. Cancel and failure both read as false;
    /// the caller decides whether to keep the gate up or roll a switch back.
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
