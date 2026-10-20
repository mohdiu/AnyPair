import Foundation

/// A pairing file this app created. Files live in Documents, so they also show
/// in the Files app under On My iPhone › AnyPair.
struct PairingRecord: Codable, Identifiable, Equatable {
    var fileName: String
    var created: Date
    var deviceName: String?
    var identity: HostIdentity

    var id: String { fileName }

    var url: URL { PairingFileStore.directory.appendingPathComponent(fileName) }
}

@MainActor
final class PairingFileStore: ObservableObject {
    @Published private(set) var records: [PairingRecord] = []

    private static let indexKey = "anypair.records"

    nonisolated static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        load()
    }

    /// Writes a new pairing file and returns its record.
    func save(_ data: Data, deviceName: String?, identity: HostIdentity) throws -> PairingRecord {
        let stamp = Self.fileStamp.string(from: Date())
        let device = Self.sanitize(deviceName ?? "iPhone")
        var fileName = "rp_pairing_\(device)_\(stamp).plist"
        var counter = 2
        while FileManager.default.fileExists(atPath: Self.directory.appendingPathComponent(fileName).path) {
            fileName = "rp_pairing_\(device)_\(stamp)_\(counter).plist"
            counter += 1
        }

        let record = PairingRecord(fileName: fileName, created: Date(), deviceName: deviceName, identity: identity)
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try data.write(to: record.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        records.insert(record, at: 0)
        persist()
        return record
    }

    func delete(_ record: PairingRecord) {
        try? FileManager.default.removeItem(at: record.url)
        records.removeAll { $0.id == record.id }
        persist()
    }

    /// Drops records whose file was deleted from the Files app.
    func load() {
        let stored = UserDefaults.standard.data(forKey: Self.indexKey)
            .flatMap { try? JSONDecoder().decode([PairingRecord].self, from: $0) } ?? []
        records = stored.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        if records.count != stored.count { persist() }
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(records), forKey: Self.indexKey)
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let cleaned = name.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "iPhone" : String(trimmed.prefix(40))
    }
}
