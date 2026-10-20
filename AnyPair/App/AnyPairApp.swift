import SwiftUI
import UserNotifications

@main
struct AnyPairApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PairingFileStore()
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue

    init() {
        AppLanguage.applyToUIKit()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(AnyPairTheme.accent)
                .appLayoutDirection()
                // Rebuild the UI when the in-app language changes.
                .id(language)
                .onChange(of: language) { _, _ in
                    AppLanguage.applyToUIKit()
                }
        }
    }
}

/// Shows the pairing-code notification even while AnyPair is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
