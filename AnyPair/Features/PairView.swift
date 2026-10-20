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
            VStack(spacing: 24) {
                Spacer()
                status
                Spacer()
                actions
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(identity.name)
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
        .onAppear {
            if service.phase == .idle {
                service.start(identity: identity, useAudio: useAudio, useLocation: useLocation, store: store)
            }
        }
        .onDisappear { service.reset() }
        .onChange(of: service.phase) { _, phase in
            if case .succeeded = phase {
                askToShare = true
            }
        }
        .confirmationDialog(tr("تم الإقران", "Paired"), isPresented: $askToShare, titleVisibility: .visible) {
            if let record {
                Button(tr("مشاركة الملف", "Share file")) { fileAction = .share(record.url) }
                Button(tr("حفظ في الملفات", "Save to Files")) { fileAction = .saveToFiles(record.url) }
            }
            Button(tr("لاحقًا", "Later"), role: .cancel) {}
        }
        .fileActionSheet($fileAction)
    }

    private var record: PairingRecord? {
        if case .succeeded(let record) = service.phase { return record }
        return nil
    }

    @ViewBuilder
    private var status: some View {
        VStack(spacing: 16) {
            switch service.phase {
            case .idle, .preparing, .advertising:
                ProgressView()
                    .controlSize(.large)
                Text("Pair with \(identity.name)".bidiIsolated)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            case .deviceConnected:
                ProgressView()
                    .controlSize(.large)
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
            case .awaitingPIN(let pin):
                Text(pin.bidiIsolated)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .tracking(10)
                    .monospacedDigit()
                    .foregroundStyle(AnyPairTheme.accent)
                    .textSelection(.enabled)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AnyPairTheme.statusGood)
                Text(tr("تم الإقران", "Paired"))
                    .font(.title2.weight(.bold))
            case .failed(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AnyPairTheme.statusBad)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut, value: service.phase)
    }

    @ViewBuilder
    private var actions: some View {
        switch service.phase {
        case .idle, .failed:
            Button(tr("إعادة المحاولة", "Try again")) {
                service.start(identity: identity, useAudio: useAudio, useLocation: useLocation, store: store)
            }
            .buttonStyle(PillButtonStyle(filled: true))
        case .succeeded(let record):
            HStack(spacing: 12) {
                Button(tr("مشاركة", "Share")) { fileAction = .share(record.url) }
                    .buttonStyle(PillButtonStyle(filled: true))
                Button(tr("الملفات", "Files")) { fileAction = .saveToFiles(record.url) }
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
