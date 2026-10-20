import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AnyPairWidgetBundle: WidgetBundle {
    var body: some Widget {
        PairingLiveActivity()
    }
}

struct PairingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PairingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LockScreenView(context: context)
                }
            } compactLeading: {
                Image(systemName: "link")
                    .foregroundStyle(accent)
            } compactTrailing: {
                CompactTrailing(state: context.state)
            } minimal: {
                Image(systemName: icon(context.state.step))
                    .foregroundStyle(color(context.state.step))
            }
        }
    }
}

private let accent = Color(red: 0.23, green: 0.59, blue: 0.98)

private func icon(_ step: PairingActivityAttributes.ContentState.Step) -> String {
    switch step {
    case .waiting: return "hourglass"
    case .connected: return "iphone.radiowaves.left.and.right"
    case .pin: return "number"
    case .done: return "checkmark.circle.fill"
    case .failed: return "xmark.circle.fill"
    }
}

private func color(_ step: PairingActivityAttributes.ContentState.Step) -> Color {
    switch step {
    case .done: return .green
    case .failed: return .red
    default: return accent
    }
}

private struct CompactTrailing: View {
    let state: PairingActivityAttributes.ContentState

    var body: some View {
        if state.step == .pin, let pin = state.pin {
            Text(pin)
                .font(.system(.body, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(accent)
        } else {
            Image(systemName: icon(state.step))
                .foregroundStyle(color(state.step))
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<PairingActivityAttributes>

    private func t(_ ar: String, _ en: String) -> String {
        context.attributes.arabic ? ar : en
    }

    var body: some View {
        VStack(spacing: 6) {
            switch context.state.step {
            case .waiting:
                Label(t("بانتظار الإقران…", "Waiting to pair…"), systemImage: "hourglass")
                    .font(.headline)
                Text("Pair with \(context.attributes.hostName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .connected:
                Label(t("أدخل رمز الجوال…", "Enter your passcode…"), systemImage: "lock.fill")
                    .font(.headline)
            case .pin:
                Text(context.state.pin ?? "")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .tracking(8)
                    .monospacedDigit()
                    .foregroundStyle(accent)
            case .done:
                Label(t("تم الإقران", "Paired"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            case .failed:
                Label(t("فشل الإقران", "Pairing failed"), systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, context.attributes.arabic ? .rightToLeft : .leftToRight)
    }
}
