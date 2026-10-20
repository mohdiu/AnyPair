import SwiftUI

struct FilesView: View {
    @EnvironmentObject private var store: PairingFileStore
    @Environment(\.dismiss) private var dismiss

    @State private var fileAction: FileAction?
    @State private var expanded: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        tr("لا توجد ملفات بعد", "No pairing files yet"),
                        systemImage: "doc.badge.plus"
                    )
                } else {
                    List {
                        Section {
                            ForEach(store.records) { record in
                                recordRow(record)
                            }
                            .onDelete { offsets in
                                offsets.map { store.records[$0] }.forEach { store.delete($0) }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(tr("الملفات", "Files"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إغلاق", "Close")) { dismiss() }
                }
            }
        }
        .onAppear { store.load() }
        .fileActionSheet($fileAction)
    }

    private func recordRow(_ record: PairingRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded = expanded == record.id ? nil : record.id }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text((record.deviceName ?? "iPhone").bidiIsolated)
                        .font(.headline)
                    Text(record.created.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.identity.name.bidiIsolated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded == record.id {
                Text(record.fileName.bidiIsolated)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                IdentityRows(identity: record.identity)
            }

            HStack(spacing: 10) {
                Button {
                    fileAction = .share(record.url)
                } label: {
                    Label(tr("مشاركة", "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    fileAction = .saveToFiles(record.url)
                } label: {
                    Label(tr("الملفات", "Files"), systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 6)
    }
}
