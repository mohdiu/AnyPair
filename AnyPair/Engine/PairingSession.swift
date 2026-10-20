import Darwin
import Foundation
import idevice

/// One device-initiated pairing (iOS 27+), run off the main thread.
///
/// 1. idevice generates a fresh host identity (`pairable_host_prepare_custom`).
/// 2. `PairableHostAdvertiser` publishes it over Bonjour and relays the device's
///    connection to a loopback socket owned by this session.
/// 3. The accepted loopback socket is handed to `pairable_host_accept_fd`, which
///    runs pair-setup and returns the RPPairing file.
final class PairingSession: @unchecked Sendable {
    enum Event {
        case connected
        case pin(String)
        case succeeded(file: Data, deviceName: String?)
        case failed(String)
        case cancelled
    }

    let serviceIdentifier: String
    let txtRecords: [String: String]
    let loopbackPort: UInt16

    private let handle: OpaquePointer
    private let listenFD: Int32
    private let onEvent: (Event) -> Void
    private let lock = NSLock()
    private var cancelled = false
    private var clientFD: Int32 = -1

    /// `onEvent` is called on a background thread.
    init(identity: HostIdentity, onEvent: @escaping (Event) -> Void) throws {
        self.onEvent = onEvent

        var outHandle: OpaquePointer?
        var outServiceID: UnsafeMutablePointer<CChar>?
        var outTXT: UnsafeMutablePointer<UInt8>?
        var outTXTLength: UInt = 0

        let name = strdup(identity.name)
        let model = strdup(identity.model)
        let identifier = identity.identifier.flatMap { strdup($0) }
        let serial = identity.serialNumber.flatMap { strdup($0) }
        let udid = identity.udid.flatMap { strdup($0) }
        defer { [name, model, identifier, serial, udid].forEach { free(UnsafeMutableRawPointer($0)) } }
        let mac = identity.mac ?? []

        let error = mac.withUnsafeBufferPointer { macBuffer in
            pairable_host_prepare_custom(
                UnsafePointer(name),
                UnsafePointer(model),
                UnsafePointer(identifier),
                UnsafePointer(serial),
                identity.mac == nil ? nil : macBuffer.baseAddress,
                UnsafePointer(udid),
                &outHandle,
                &outServiceID,
                &outTXT,
                &outTXTLength,
                nil
            )
        }
        if let error { throw PairingError(consuming: error) }
        guard let outHandle, let outServiceID, let outTXT else {
            throw PairingError(message: tr("تعذّر تجهيز هوية الإقران.", "Couldn’t prepare the pairing identity."))
        }

        serviceIdentifier = String(cString: outServiceID)
        idevice_string_free(outServiceID)
        let txtData = Data(bytes: outTXT, count: Int(outTXTLength))
        idevice_data_free(outTXT, outTXTLength)
        txtRecords = (try? PropertyListSerialization.propertyList(from: txtData, format: nil)) as? [String: String] ?? [:]

        let loopback: (fd: Int32, port: UInt16)
        do {
            loopback = try Self.makeLoopbackListener()
        } catch {
            pairable_host_free(outHandle)
            throw error
        }
        listenFD = loopback.fd
        loopbackPort = loopback.port
        handle = outHandle
    }

    /// Starts waiting for the device on a background thread.
    func start() {
        let thread = Thread { [self] in
            run()
        }
        thread.name = "anypair.pairing"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Stops waiting / aborts an in-progress pair-setup. Safe from any thread.
    func cancel() {
        lock.lock()
        cancelled = true
        let fd = clientFD
        lock.unlock()
        if fd >= 0 {
            // Unblocks the read inside pairable_host_accept_fd.
            shutdown(fd, SHUT_RDWR)
        }
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    // MARK: Worker

    private func run() {
        defer {
            Darwin.close(listenFD)
            pairable_host_free(handle)
        }

        // Wait for the relayed connection, checking for cancel twice a second.
        var fd: Int32 = -1
        while fd < 0 {
            if isCancelled {
                onEvent(.cancelled)
                return
            }
            var pfd = pollfd(fd: listenFD, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, 500)
            if ready > 0 {
                fd = Darwin.accept(listenFD, nil, nil)
            } else if ready < 0, errno != EINTR {
                onEvent(.failed(String(cString: strerror(errno))))
                return
            }
        }

        lock.lock()
        clientFD = fd
        let cancelledEarly = cancelled
        lock.unlock()
        defer {
            lock.lock()
            clientFD = -1
            lock.unlock()
            Darwin.close(fd)
        }
        if cancelledEarly {
            onEvent(.cancelled)
            return
        }

        AppLog.write("loopback accepted, running pair-setup")
        onEvent(.connected)

        var peer: UnsafeMutablePointer<RpPairingPeerDeviceC>?
        var file: OpaquePointer?
        let context = Unmanaged.passUnretained(self).toOpaque()
        let error = pairable_host_accept_fd(handle, fd, pinTrampoline, context, &peer, &file)

        if let error {
            let failure = PairingError(consuming: error)
            AppLog.write("pair-setup error: \(failure.message)")
            onEvent(isCancelled ? .cancelled : .failed(failure.message))
            return
        }

        var deviceName: String?
        if let peer {
            deviceName = peer.pointee.name.map { String(cString: $0) }
            rppairing_peer_device_free(peer)
        }

        guard let file else {
            onEvent(.failed(tr("انتهى الإقران لكن لم يُرجَع ملف.", "Pairing finished but no file was returned.")))
            return
        }
        defer { rp_pairing_file_free(file) }

        var bytes: UnsafeMutablePointer<UInt8>?
        var length: UInt = 0
        if let error = rp_pairing_file_to_bytes(file, &bytes, &length) {
            onEvent(.failed(PairingError(consuming: error).message))
            return
        }
        guard let bytes else {
            onEvent(.failed(tr("ملف الإقران فارغ.", "The pairing file is empty.")))
            return
        }
        let data = Data(bytes: bytes, count: Int(length))
        idevice_data_free(bytes, length)
        onEvent(.succeeded(file: data, deviceName: deviceName))
    }

    fileprivate func deliverPIN(_ pin: String) {
        onEvent(.pin(pin))
    }

    // MARK: Loopback socket

    private static func makeLoopbackListener() throws -> (Int32, UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw PairingError.posix("socket") }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)

        let bound = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer -> Bool in
                bind(fd, pointer, length) == 0
                    && listen(fd, 4) == 0
                    && getsockname(fd, pointer, &length) == 0
            }
        }
        guard bound else {
            let error = PairingError.posix("bind")
            Darwin.close(fd)
            throw error
        }
        return (fd, UInt16(bigEndian: addr.sin_port))
    }
}

private func pinTrampoline(pin: UnsafePointer<CChar>?, context: UnsafeMutableRawPointer?) {
    guard let pin, let context else { return }
    let session = Unmanaged<PairingSession>.fromOpaque(context).takeUnretainedValue()
    session.deliverPIN(String(cString: pin))
}

struct PairingError: LocalizedError {
    let message: String

    var errorDescription: String? { message }

    init(message: String) {
        self.message = message
    }

    /// Reads and frees an idevice error.
    init(consuming error: UnsafeMutablePointer<IdeviceFfiError>) {
        if let text = error.pointee.message {
            message = String(cString: text)
        } else {
            message = tr("خطأ إقران غير معروف (\(error.pointee.code))", "Unknown pairing error (\(error.pointee.code))")
        }
        idevice_error_free(error)
    }

    static func posix(_ call: String) -> PairingError {
        PairingError(message: "\(call): \(String(cString: strerror(errno)))")
    }
}
