import ActivityKit
import Foundation

/// Live Activity shown in the Dynamic Island / Lock Screen while pairing.
struct PairingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Step: String, Codable, Hashable {
            case waiting
            case connected
            case pin
            case done
            case failed
        }

        var step: Step
        var pin: String?
    }

    var hostName: String
    var arabic: Bool
}
