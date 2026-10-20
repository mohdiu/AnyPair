import Foundation
import UIKit
import UserNotifications

/// Drives one pairing for the UI: permissions, keep-alive, Bonjour, PIN, saving.
@MainActor
final class PairingService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case advertising
        case deviceConnected
        case awaitingPIN(String)
        case succeeded(PairingRecord)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var identity: HostIdentity?

    private var session: PairingSession?
    private let advertiser = PairableHostAdvertiser()
    private let location = LocationKeepAlive()
    private let audio = SilentAudioKeepAlive()
    private let liveActivity = PairingActivity()
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    var isBusy: Bool {
        switch phase {
        case .preparing, .advertising, .deviceConnected, .awaitingPIN: return true
        default: return false
        }
    }

    /// The device has connected (Developer Mode steps done).
    var deviceReached: Bool {
        switch phase {
        case .deviceConnected, .awaitingPIN, .succeeded: return true
        default: return false
        }
    }

    func start(identity: HostIdentity, useAudio: Bool, useLocation: Bool, store: PairingFileStore) {
        guard !isBusy else { return }
        self.identity = identity
        phase = .preparing
        liveActivity.start(hostName: identity.name)

        // One prompt at a time: Location, Notifications, then Local Network
        // (iOS shows that one when the listener starts).
        Task { @MainActor in
            if useLocation {
                await location.requestAuthorization()
            }
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard phase == .preparing else { return }

            do {
                let session = try PairingSession(identity: identity) { [weak self] event in
                    DispatchQueue.main.async {
                        self?.handle(event, store: store)
                    }
                }
                self.session = session
                beginKeepAlive(useAudio: useAudio, useLocation: useLocation)
                advertiser.publish(
                    serviceIdentifier: session.serviceIdentifier,
                    txt: session.txtRecords,
                    relayPort: session.loopbackPort
                )
                session.start()
                phase = .advertising
            } catch {
                liveActivity.end(.failed)
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        session?.cancel()
        session = nil
        teardown()
        liveActivity.end(.failed, immediately: true)
        phase = .idle
    }

    func reset() {
        if isBusy { cancel() }
        phase = .idle
    }

    private func handle(_ event: PairingSession.Event, store: PairingFileStore) {
        guard session != nil else { return }
        switch event {
        case .connected:
            phase = .deviceConnected
            liveActivity.update(.connected)
        case .pin(let pin):
            phase = .awaitingPIN(pin)
            liveActivity.update(.pin, pin: pin)
            if !liveActivity.isRunning {
                Self.notify(title: tr("رمز إقران AnyPair", "AnyPair pairing code"), body: pin, id: "anypair.pin", urgent: true)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .succeeded(let data, let deviceName):
            session = nil
            teardown()
            let identity = identity ?? .fixed(name: "AnyPair")
            do {
                let record = try store.save(data, deviceName: deviceName, identity: identity)
                HostIdentity.lastUsed = identity
                phase = .succeeded(record)
                liveActivity.end(.done)
            } catch {
                liveActivity.end(.failed)
                phase = .failed(tr("تم الإقران لكن فشل حفظ الملف: ", "Paired, but saving the file failed: ") + error.localizedDescription)
            }
        case .failed(let message):
            session = nil
            teardown()
            liveActivity.end(.failed)
            phase = .failed(message)
        case .cancelled:
            break
        }
    }

    private func teardown() {
        advertiser.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        location.stop()
        audio.stop()
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func beginKeepAlive(useAudio: Bool, useLocation: Bool) {
        UIApplication.shared.isIdleTimerDisabled = true
        if useLocation { location.start() }
        if useAudio { audio.start() }
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "anypair.pairing") { [weak self] in
            guard let self, self.backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
    }

    private static func notify(title: String, body: String, id: String? = nil, urgent: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if urgent {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(identifier: id ?? "anypair.status.\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
