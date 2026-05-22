import Foundation

enum AlarmFeatureFlags {
    /// Experimental best-effort output-volume floor adjustment using MPVolumeView.
    /// Keep disabled if App Store behavior is undesirable for a release branch.
    static let experimentalMPVolumeOutputFloor = true
}
