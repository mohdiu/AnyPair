import Foundation
import Network

/// Public-facing pairable-host listener (from AnyGPS).
///
/// Uses Network.framework `NWListener` + Bonjour (what iOS 27 Developer Mode
/// browses). Inbound connections are relayed to the app's loopback socket on
/// 127.0.0.1 so accept() still completes while Settings is in the foreground.
final class PairableHostAdvertiser {
    private var listener: NWListener?
    private var activeRelay: RelayPipe?
    private(set) var publishedPort: UInt16 = 0
    private var loopbackPort: UInt16 = 0

    /// Publishes `_remotepairing-pairable-host._tcp` and relays every inbound
    /// connection to `relayPort` on 127.0.0.1.
    func publish(serviceIdentifier: String, txt records: [String: String], relayPort port: UInt16) {
        stop()
        loopbackPort = port

        var txt = NWTXTRecord()
        for (key, value) in records {
            txt[key] = value
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: serviceIdentifier,
                type: "_remotepairing-pairable-host._tcp",
                domain: "local",
                txtRecord: txt
            )

            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    let p = listener.port?.rawValue ?? 0
                    self?.publishedPort = p
                    AppLog.write("listener ready on port \(p), relay → 127.0.0.1:\(port)")
                case .failed(let error):
                    AppLog.write("listener failed: \(error)")
                case .cancelled:
                    AppLog.write("listener cancelled")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                AppLog.write("device connected from \(connection.endpoint)")
                self?.relay(connection)
            }

            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
            AppLog.write("advertising \(serviceIdentifier)")
        } catch {
            AppLog.write("listener start failed: \(error)")
        }
    }

    func stop() {
        activeRelay?.cancel(reason: "stop")
        activeRelay = nil
        listener?.cancel()
        listener = nil
    }

    /// Stops advertising but lets the current relay finish delivering the last
    /// message; the device closes it (or it is cut after `timeout`).
    func stopAfterRelayDrains(timeout: TimeInterval = 10) {
        listener?.cancel()
        listener = nil
        guard let relay = activeRelay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            relay.cancel(reason: "drain timeout")
            if self?.activeRelay === relay { self?.activeRelay = nil }
        }
    }

    private func relay(_ inbound: NWConnection) {
        activeRelay?.cancel(reason: "replaced by a new connection")
        let rustPort = loopbackPort
        guard rustPort > 0, let nwPort = NWEndpoint.Port(rawValue: rustPort) else {
            inbound.cancel()
            return
        }

        let outbound = NWConnection(
            host: NWEndpoint.Host("127.0.0.1"),
            port: nwPort,
            using: .tcp
        )
        let pipe = RelayPipe(inbound: inbound, outbound: outbound)
        activeRelay = pipe
        pipe.start()
    }
}

/// Bidirectional byte pump between Developer Mode and the loopback listener.
/// An end-of-stream on one side is passed on as a half-close (FIN) so the last
/// message is delivered before the device closes its side.
private final class RelayPipe {
    private let inbound: NWConnection
    private let outbound: NWConnection
    private let queue = DispatchQueue(label: "anypair.relay")
    private var cancelled = false
    private var finished = 0

    init(inbound: NWConnection, outbound: NWConnection) {
        self.inbound = inbound
        self.outbound = outbound
    }

    func start() {
        inbound.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error): self?.cancel(reason: "device connection failed: \(error)")
            case .cancelled: self?.cancel(reason: "device connection cancelled")
            default: break
            }
        }
        outbound.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                AppLog.write("relay connected to loopback")
                self.pump(from: self.inbound, to: self.outbound, name: "device→host")
                self.pump(from: self.outbound, to: self.inbound, name: "host→device")
            case .failed(let error):
                self.cancel(reason: "loopback failed: \(error)")
            case .cancelled:
                self.cancel(reason: "loopback cancelled")
            default:
                break
            }
        }
        inbound.start(queue: queue)
        outbound.start(queue: queue)
    }

    func cancel(reason: String) {
        queue.async { [self] in
            guard !cancelled else { return }
            cancelled = true
            AppLog.write("relay closed: \(reason)")
            inbound.cancel()
            outbound.cancel()
        }
    }

    private func pump(from: NWConnection, to: NWConnection, name: String) {
        from.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.cancel(reason: "\(name) receive error: \(error)")
                return
            }
            let count = data?.count ?? 0
            guard count > 0 || isComplete else {
                self.pump(from: from, to: to, name: name)
                return
            }
            AppLog.write("\(name) \(count) bytes\(isComplete ? " + end" : "")")
            // Forward the bytes; on end-of-stream also send FIN to the other side.
            to.send(content: count > 0 ? data : nil, contentContext: isComplete ? .finalMessage : .defaultMessage, isComplete: isComplete, completion: .contentProcessed { sendError in
                if let sendError {
                    self.cancel(reason: "\(name) send error: \(sendError)")
                    return
                }
                if isComplete {
                    self.queue.async {
                        self.finished += 1
                        if self.finished == 2 {
                            self.cancel(reason: "both sides finished")
                        }
                    }
                } else {
                    self.pump(from: from, to: to, name: name)
                }
            })
        }
    }
}
