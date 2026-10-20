import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PairingFileStore

    @AppStorage("anypair.keepAlive.audio") private var useAudio = true
    @AppStorage("anypair.keepAlive.location") private var useLocation = true
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue

    @State private var next = HostIdentity.random(excluding: HostIdentity.lastUsed)
    @State private var pairing: HostIdentity?
    @State private var showFiles = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 12)

                    nameCard

                    Button(tr("إقران", "Pair")) {
                        next.name = next.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if next.name.isEmpty {
                            next = HostIdentity.random(excluding: next)
                        }
                        pairing = next
                    }
                    .buttonStyle(PillButtonStyle(filled: true))

                    Button {
                        showFiles = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(tr("الملفات", "Files"))
                            if !store.records.isEmpty {
                                Text("\(store.records.count)")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AnyPairTheme.accent))
                            }
                        }
                    }
                    .buttonStyle(PillButtonStyle())

                    keepAliveCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    languageMenu
                }
            }
        }
        .sheet(item: $pairing, onDismiss: {
            // A finished pairing used this identity; never offer it again.
            if HostIdentity.lastUsed == next {
                next = HostIdentity.random(excluding: next)
            }
        }) { identity in
            PairView(identity: identity, useAudio: useAudio, useLocation: useLocation)
                .appLayoutDirection()
        }
        .sheet(isPresented: $showFiles) {
            FilesView()
                .appLayoutDirection()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            Text("AnyPair")
                .font(.system(size: 44, weight: .bold))
        }
    }

    private var nameCard: some View {
        HStack(spacing: 12) {
            TextField(tr("الاسم", "Name"), text: $next.name)
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                withAnimation { next = HostIdentity.random(excluding: next) }
            } label: {
                Image(systemName: "dice.fill")
                    .font(.title2)
                    .foregroundStyle(AnyPairTheme.accent)
            }
            .accessibilityLabel(tr("توليد عشوائي", "Randomize"))
        }
        .card()
    }

    private var keepAliveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("البقاء في الخلفية", "Background keep-alive"))
                .font(.headline)
            Toggle(tr("صوت صامت", "Silent audio"), isOn: $useAudio)
                .tint(AnyPairTheme.accent)
            Toggle(tr("الموقع", "Location"), isOn: $useLocation)
                .tint(AnyPairTheme.accent)
        }
        .card()
    }

    private var languageMenu: some View {
        Menu {
            Picker(tr("اللغة", "Language"), selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "globe")
        }
    }
}

/// Name / model / serial / MAC / identifier / UDID.
struct IdentityRows: View {
    let identity: HostIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(tr("الاسم", "Name"), identity.name)
            row(tr("الموديل", "Model"), identity.model)
            row(tr("الرقم التسلسلي", "Serial"), identity.serialString)
            row("MAC", identity.macString)
            row(tr("المعرّف", "Identifier"), identity.identifier ?? "—")
            row("UDID", identity.udid ?? "—")
        }
        .font(.footnote)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value.bidiIsolated)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
        }
    }
}

extension HostIdentity: Identifiable {
    var id: String { (identifier ?? name) + model + serialString }
}
