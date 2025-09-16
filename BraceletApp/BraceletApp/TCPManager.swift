import Foundation
import Network

class TCPManager: ObservableObject {
    
    @Published var messages: [String] = []
    @Published var connectionState: String = "Disconnected"
    
    private var connection: NWConnection?
    private let connectionQueue = DispatchQueue(label: "com.yourapp.tcpmanager")

    // MARK: - Public API for Foreground App
    
    func connect(host: String, port: Int) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 2
        
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        
        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            self.updateConnectionState("Invalid Port")
            return
        }
        let endpoint = NWEndpoint.Host(host)
        self.connection = NWConnection(host: endpoint, port: port, using: params)

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.updateConnectionState("Connected")
                    self?.receiveData()
                case .failed(let error):
                    self?.updateConnectionState("Failed: \(error.localizedDescription)")
                    self?.connection?.cancel()
                default:
                    self?.updateConnectionState("State: \(newState)")
                }
            }
        }
        
        connection?.start(queue: connectionQueue)
    }

    func send(message: String) {
        guard let connection = self.connection else { return }
        let data = Data((message + "\n").utf8)
        connection.send(content: data, completion: .contentProcessed({ [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.addMessage(message.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }))
    }
    
    func disconnect() {
        connection?.cancel()
        self.connection = nil
    }
    
    // MARK: - Public API for Background Tasks
    
    /// Creates a short-lived connection to send a single message. Ideal for background tasks.
    func sendBackgroundTask(host: String, port: Int, message: String) {
        print("Initiating background TCP task...")
        
        let params = NWParameters.tcp
        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else { return }
        let endpoint = NWEndpoint.Host(host)
        let connection = NWConnection(host: endpoint, port: port, using: params)

        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                let data = Data((message + "\n").utf8)
                connection.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        print("Background TCP send error: \(error)")
                    } else {
                        print("Background TCP send successful.")
                    }
                    connection.cancel()
                }))
            case .failed(let error):
                print("Background TCP connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global())
    }
    
    // MARK: - Private Helpers
    
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            if let data = data, !data.isEmpty, let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.addMessage("[Server]: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            if isComplete || error != nil {
                self?.disconnect()
            } else {
                self?.receiveData()
            }
        }
    }
    
    private func updateConnectionState(_ state: String) {
        DispatchQueue.main.async { self.connectionState = state }
    }
    
    private func addMessage(_ message: String) {
        DispatchQueue.main.async { self.messages.append(message) }
    }
}
