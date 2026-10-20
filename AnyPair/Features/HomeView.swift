import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PairingFileStore

    @AppStorage("anypair.randomIdentity") private var randomIdentity = true
    @AppStorage("anypair.hostName") private var hostName = "AnyPair"
    @AppStorage("anypair.keepAlive.audio") private var useAudio = true
    @AppStorage("anypair.keepAlive.location") private var useLocation = true
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue

    @State private var nextRandom = HostIdentity.random(excluding: HostIdentity.lastUsed)
    @State private var pairing: HostIdentity?
    @State private var showFiles = false

    private var nextIdentity: HostIdentity {
        randomIdentity ? nextRandom : .fixed(name: hostName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                        .padding(.top, 12)

                    Button(tr("إقران آيفون أو آيباد", "Pair iPhone or iPad")) {
                        pairing = nextIdentity
                    }
                    .buttonStyle(PillButtonStyle())

                    Button {
                        showFiles = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(tr("ملفات الإقران", "Pairing files"))
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

                    identityCard
                    keepAliveCard
                    requirementsNote
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    languageMenu
                }
            }
        }
        .sheet(item: $pairing, onDismiss: {
            // A finished pairing used this identity; never offer it again.
            if randomIdentity, HostIdentity.lastUsed == nextRandom {
                nextRandom = HostIdentity.random(excluding: nextRandom)
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
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            Text("AnyPair")
                .font(.system(size: 44, weight: .bold))
            Text(tr("أنشئ ملف إقران (RPPairing) وشاركه مع أي تطبيق.", "Create an RPPairing file and share it with any app."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $randomIdentity.animation()) {
                Text(tr("قيم عشوائية لكل إقران", "Random values for each pairing"))
                    .font(.headline)
            }
            .tint(AnyPairTheme.accent)

            Text(randomIdentity
                 ? tr("كل عملية إقران تأخذ اسمًا وموديلًا ورقمًا تسلسليًا وعنوان MAC ومعرّفًا جديدًا بدل القيم الثابتة (AAAAAAAAAAAA)، ولا تتكرر قيم الإقران السابق.",
                      "Each pairing gets a new name, model, serial number, MAC address and identifier instead of the fixed values (AAAAAAAAAAAA), and never repeats the previous pairing’s values.")
                 : tr("القيم ثابتة: كل إقران بنفس الاسم يظهر للآيفون كنفس الجهاز، وقد يُلغي الملف السابق.",
                      "Fixed values: every pairing with the same name looks like the same computer to the iPhone and may replace the previous file."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Label {
                Text(tr("يُنصح باستخدام ملف إقران مختلف لكل تطبيق (مثلًا ملف لـ AnyGPS وملف آخر لـ StikDebug)، فلا يتأثر تطبيق إذا أعدت الإقران لتطبيق آخر.",
                        "Tip: use a different pairing file for each app (for example one for AnyGPS and another for StikDebug), so re-pairing for one app doesn’t affect the others."))
                    .font(.footnote)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AnyPairTheme.statusWarn)
            }

            Divider().overlay(AnyPairTheme.cardStroke)

            if randomIdentity {
                HStack {
                    Text(tr("الإقران القادم", "Next pairing"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation { nextRandom = HostIdentity.random(excluding: nextRandom) }
                    } label: {
                        Label(tr("توليد جديد", "Regenerate"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("اسم الجهاز الظاهر", "Name shown on the iPhone"))
                        .font(.subheadline.weight(.semibold))
                    TextField("AnyPair", text: $hostName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            IdentityRows(identity: nextIdentity)
        }
        .card()
    }

    // MARK: Keep-alive

    private var keepAliveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("البقاء في الخلفية", "Background keep-alive"))
                .font(.headline)
            Toggle(tr("صوت صامت", "Silent audio"), isOn: $useAudio)
                .tint(AnyPairTheme.accent)
            Toggle(tr("الموقع", "Location"), isOn: $useLocation)
                .tint(AnyPairTheme.accent)
            Text(tr("يُبقيان التطبيق شغالًا وأنت في الإعدادات. إذا لم يظهر AnyPair في نمط المطور أو لم يصل الرمز، فعّل الاثنين.",
                    "These keep the app running while you’re in Settings. If AnyPair doesn’t show in Developer Mode or the code never arrives, turn both on."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var requirementsNote: some View {
        Text(tr("يتطلب iOS 27 أو أحدث، ونمط المطور مفعّل، ونفس شبكة الواي فاي.",
                "Requires iOS 27 or later, Developer Mode on, and the same Wi‑Fi network."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
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

/// Name / model / serial / MAC / identifier / UDID, with copy-friendly text.
struct IdentityRows: View {
    let identity: HostIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(tr("الاسم", "Name"), identity.name)
            row(tr("الموديل", "Model"), identity.model)
            row(tr("الرقم التسلسلي", "Serial"), identity.serialString)
            row("MAC", identity.macString)
            row(tr("المعرّف", "Identifier"), identity.identifier ?? tr("مشتق من الاسم", "Derived from name"))
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
