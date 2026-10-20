import Foundation

/// What this app tells the iPhone about itself during pairing. iOS stores these
/// values in its trusted-host record for the pairing file.
///
/// Fixed mode keeps idevice's defaults (serial `AAAAAAAAAAAA`, MAC
/// `11:22:33:44:55:66`, identifier derived from the name), so every pairing looks
/// like the same computer. Random mode gives each pairing its own values.
struct HostIdentity: Codable, Equatable {
    var name: String
    var model: String
    /// nil = derived from `name` by idevice (same name → same identifier).
    var identifier: String?
    /// nil = idevice default `AAAAAAAAAAAA`.
    var serialNumber: String?
    /// nil = idevice default `11:22:33:44:55:66`.
    var mac: [UInt8]?
    /// nil = empty.
    var udid: String?

    var isRandom: Bool { identifier != nil }

    static let defaultModel = "Mac17,7"
    static let defaultSerial = "AAAAAAAAAAAA"
    static let defaultMAC = "11:22:33:44:55:66"

    static func fixed(name: String) -> HostIdentity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return HostIdentity(name: trimmed.isEmpty ? "AnyPair" : trimmed, model: defaultModel)
    }

    var macString: String {
        guard let mac else { return Self.defaultMAC }
        return mac.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    var serialString: String { serialNumber ?? Self.defaultSerial }

    // MARK: Random

    /// Model identifier → name iOS shows ("Pair with MacBook Pro").
    private static let macs: [(model: String, name: String)] = [
        ("Mac14,2", "MacBook Air"),
        ("Mac14,15", "MacBook Air"),
        ("Mac15,12", "MacBook Air"),
        ("Mac16,12", "MacBook Air"),
        ("Mac14,7", "MacBook Pro"),
        ("Mac14,9", "MacBook Pro"),
        ("Mac15,3", "MacBook Pro"),
        ("Mac15,6", "MacBook Pro"),
        ("Mac16,1", "MacBook Pro"),
        ("Mac16,5", "MacBook Pro"),
        ("Mac14,3", "Mac mini"),
        ("Mac16,10", "Mac mini"),
        ("Mac15,4", "iMac"),
        ("Mac16,2", "iMac"),
        ("Mac13,1", "Mac Studio"),
        ("Mac14,13", "Mac Studio"),
    ]

    /// Apple OUIs so the MAC looks like a real Mac.
    private static let appleOUIs: [[UInt8]] = [
        [0xF0, 0x18, 0x98], [0x3C, 0x22, 0xFB], [0xA4, 0x83, 0xE7], [0x88, 0x66, 0x5A],
        [0x14, 0x7D, 0xDA], [0xBC, 0xD0, 0x74], [0x5C, 0xE9, 0x1E], [0xF8, 0x4D, 0x89],
    ]

    /// Apple-silicon chip IDs used as the first part of a Mac UDID.
    private static let chipIDs = ["00008103", "00008112", "00008122", "00008132", "00006000", "00006020", "00006030"]

    /// Modern Apple serials: 10 characters, no vowels that look like digits.
    private static let serialAlphabet = Array("BCDFGHJKLMNPQRTVWXYZ0123456789")
    private static let hexAlphabet = Array("0123456789ABCDEF")

    /// A new random identity. None of its values repeat `previous`.
    static func random(excluding previous: HostIdentity? = nil) -> HostIdentity {
        while true {
            var rng = SystemRandomNumberGenerator()
            let mac = macs.randomElement(using: &rng)!
            let oui = appleOUIs.randomElement(using: &rng)!
            let suffix = String((0..<4).map { _ in serialAlphabet.randomElement(using: &rng)! })
            let identity = HostIdentity(
                name: "\(mac.name) \(suffix)",
                model: mac.model,
                identifier: UUID().uuidString.lowercased(),
                serialNumber: String((0..<10).map { _ in serialAlphabet.randomElement(using: &rng)! }),
                mac: oui + (0..<3).map { _ in UInt8.random(in: 0...255, using: &rng) },
                udid: chipIDs.randomElement(using: &rng)! + "-" + String((0..<16).map { _ in hexAlphabet.randomElement(using: &rng)! })
            )
            guard let previous else { return identity }
            if identity.name != previous.name,
               identity.model != previous.model,
               identity.identifier != previous.identifier,
               identity.serialNumber != previous.serialNumber,
               identity.mac != previous.mac,
               identity.udid != previous.udid {
                return identity
            }
        }
    }

    // MARK: Persistence

    private static let lastUsedKey = "anypair.lastIdentity"

    /// The identity of the last successful pairing.
    static var lastUsed: HostIdentity? {
        get {
            guard let data = UserDefaults.standard.data(forKey: lastUsedKey) else { return nil }
            return try? JSONDecoder().decode(HostIdentity.self, from: data)
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: lastUsedKey)
        }
    }
}
