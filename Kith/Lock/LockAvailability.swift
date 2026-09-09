import Foundation

/// What the device can offer the privacy lock (Settings §6.1, §10).
/// `deviceOwnerAuthentication` always falls back to the passcode, so the lock
/// works whenever a passcode exists; the label just reflects enrolled biometry.
nonisolated enum LockAvailability: Equatable {
    /// No device passcode: the lock cannot be enabled (Settings §10).
    case passcodeNotSet
    case passcodeOnly
    case faceID
    case touchID
    case opticID

    var canEnable: Bool {
        self != .passcodeNotSet
    }

    var toggleLabel: String {
        switch self {
        case .faceID: "Require Face ID"
        case .touchID: "Require Touch ID"
        case .opticID: "Require Optic ID"
        case .passcodeOnly, .passcodeNotSet: "Require Passcode"
        }
    }

    var unlockSymbolName: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcodeOnly, .passcodeNotSet: "lock.open"
        }
    }
}
