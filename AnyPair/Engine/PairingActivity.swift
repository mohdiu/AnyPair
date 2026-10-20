import ActivityKit
import Foundation

/// Starts / updates / ends the pairing Live Activity.
@MainActor
final class PairingActivity {
    private var activity: Activity<PairingActivityAttributes>?

    var isRunning: Bool { activity != nil }

    func start(hostName: String) {
        end(.failed, immediately: true)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PairingActivityAttributes(hostName: hostName, arabic: AppLanguage.isArabic)
        let state = PairingActivityAttributes.ContentState(step: .waiting)
        activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
    }

    func update(_ step: PairingActivityAttributes.ContentState.Step, pin: String? = nil) {
        guard let activity else { return }
        let state = PairingActivityAttributes.ContentState(step: step, pin: pin)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// Shows the final state for a few seconds, then removes it.
    func end(_ step: PairingActivityAttributes.ContentState.Step, immediately: Bool = false) {
        guard let activity else { return }
        self.activity = nil
        let state = PairingActivityAttributes.ContentState(step: step)
        let policy: ActivityUIDismissalPolicy = immediately ? .immediate : .after(.now + 8)
        Task { await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: policy) }
    }
}
