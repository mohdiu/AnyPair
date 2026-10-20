import SwiftUI

struct PairView: View {
    let identity: HostIdentity
    let useAudio: Bool
    let useLocation: Bool

    @EnvironmentObject private var store: PairingFileStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = PairingService()

    @State private var askToShare = false
    @State private var fileAction: FileAction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    steps
                    statusCard
                    actions
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("هوية هذا الإقران", "This pairing’s identity"))
                            .font(.subheadline.weight(.semibold))
                        IdentityRows(identity: identity)
                    }
                    .card(padding: 16)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(tr("إقران", "Pair"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إغلاق", "Close")) {
                        service.reset()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(service.isBusy)
        .onDisappear { service.reset() }
        .onChange(of: service.phase) { _, phase in
            if case .succeeded = phase {
                askToShare = true
            }
        }
        .confirmationDialog(
            tr("تم إنشاء ملف الإقران", "Pairing file created"),
            isPresented: $askToShare,
            titleVisibility: .visible
        ) {
            if let record {
                Button(tr("مشاركة الملف", "Share file")) { fileAction = .share(record.url) }
                Button(tr("حفظ في الملفات", "Save to Files")) { fileAction = .saveToFiles(record.url) }
            }
            Button(tr("لاحقًا", "Later"), role: .cancel) {}
        } message: {
            Text(tr("تبي تشارك الملف أو تحفظه في الملفات؟ تلقاه أيضًا في «ملفات الإقران» وفي تطبيق الملفات ← على الآيفون ← AnyPair.",
                    "Share the file or save it to Files? It’s also kept under Pairing files and in Files → On My iPhone → AnyPair."))
        }
        .fileActionSheet($fileAction)
    }

    private var record: PairingRecord? {
        if case .succeeded(let record) = service.phase { return record }
        return nil
    }

    // MARK: Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            step(1, tr("اضغط «بدء الإقران» ووافق على الطلبات (الموقع، الإشعارات، الشبكة المحلية).",
                       "Tap Start pairing and allow the requests (Location, Notifications, Local Network)."),
                 done: service.phase != .idle && service.phase != .preparing)
            step(2, tr("افتح الإعدادات ← الخصوصية والأمن ← نمط المطور، وتحت «الأجهزة الأخرى» اضغط «Pair with \(identity.name)».",
                       "Open Settings → Privacy & Security → Developer Mode, and under Other Devices tap “Pair with \(identity.name)”."),
                 done: service.deviceReached)
            step(3, tr("أدخل رمز قفل الجهاز، ثم اكتب الرمز المكوّن من 6 أرقام (يصلك كإشعار وفي هذه الصفحة).",
                       "Enter your passcode, then type the 6-digit code (sent as a notification and shown here)."),
                 done: record != nil)
        }
        .card(padding: 16)
    }

    private func step(_ number: Int, _ text: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if done {
                    Image(systemName: "checkmark").font(.caption.weight(.heavy))
                } else {
                    Text("\(number)").font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(.black)
            .frame(width: 22, height: 22)
            .background(done ? AnyPairTheme.statusGood : AnyPairTheme.statusWarn, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: Status

    private var statusCard: some View {
        VStack(spacing: 12) {
            switch service.phase {
            case .idle:
                Label(tr("جاهز", "Ready"), systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            case .preparing:
                ProgressView()
                Text(tr("جارٍ التجهيز…", "Preparing…"))
            case .advertising:
                ProgressView()
                Text(tr("بانتظار نمط المطور…", "Waiting for Developer Mode…"))
                    .font(.headline)
                Text(tr("اضغط «Pair with \(identity.name)» ثم «إقران».", "Tap “Pair with \(identity.name)”, then Pair."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .deviceConnected:
                ProgressView()
                Text(tr("تم اتصال الجهاز — الرمز قادم…", "Device connected — code coming…"))
                    .font(.headline)
            case .awaitingPIN(let pin):
                Text(tr("اكتب هذا الرمز في الإعدادات", "Enter this code in Settings"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(pin.bidiIsolated)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .tracking(10)
                    .monospacedDigit()
                    .foregroundStyle(AnyPairTheme.accent)
                    .textSelection(.enabled)
            case .succeeded(let record):
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AnyPairTheme.statusGood)
                Text(tr("تم الإقران", "Paired"))
                    .font(.title3.weight(.bold))
                Text(record.fileName.bidiIsolated)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AnyPairTheme.statusWarn)
                Text(tr("فشل الإقران", "Pairing failed"))
                    .font(.title3.weight(.bold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        switch service.phase {
        case .idle, .failed:
            Button(service.phase == .idle ? tr("بدء الإقران", "Start pairing") : tr("حاول مرة أخرى", "Try again")) {
                service.start(identity: identity, useAudio: useAudio, useLocation: useLocation, store: store)
            }
            .buttonStyle(PillButtonStyle(filled: true))
        case .succeeded(let record):
            HStack(spacing: 12) {
                Button(tr("مشاركة", "Share")) { fileAction = .share(record.url) }
                    .buttonStyle(PillButtonStyle(filled: true))
                Button(tr("حفظ في الملفات", "Save to Files")) { fileAction = .saveToFiles(record.url) }
                    .buttonStyle(PillButtonStyle())
            }
        case .preparing, .advertising, .deviceConnected, .awaitingPIN:
            Button(tr("إيقاف", "Stop"), role: .destructive) {
                service.cancel()
            }
            .buttonStyle(PillButtonStyle())
        }
    }
}
