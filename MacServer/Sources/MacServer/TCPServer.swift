import Foundation
import Network

class TCPServer: @unchecked Sendable {
    private let port: NWEndpoint.Port = 9090
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    
    private var isReady = false
    var onNewConnection: (() -> Void)?

    func start() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        self.isReady = false
        
        do {
            let parameters = NWParameters.tcp
            let tcpOptions = parameters.defaultProtocolStack.transportProtocol as! NWProtocolTCP.Options
            tcpOptions.enableKeepalive = true
            tcpOptions.noDelay = true
            
            listener = try NWListener(using: parameters, on: port)
        } catch {
            print("Failed to create listener: \(error)")
            return false
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.port {
                    print("Server listening on port \(port)")
                }
                self?.isReady = true
                semaphore.signal()
            case .failed(let error):
                print("Server failed with error: \(error)")
                self?.isReady = false
                semaphore.signal()
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("New connection from: \(connection.endpoint)")
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .global())
        
        // Wait for ready or failed state
        _ = semaphore.wait(timeout: .now() + 2.0)
        return self.isReady
    }
    
    private func handleConnection(_ connection: NWConnection) {
        print("Handling new connection: \(connection.endpoint)")
        connections.append(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Connection ready: \(connection.endpoint)")
                // Connection is fully established, now we can send the initial frame
                self?.onNewConnection?()
            case .failed(let error):
                print("Connection failed: \(error)")
                self?.removeConnection(connection)
            case .cancelled:
                // self?.removeConnection(connection) // Already removed usually
                break
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        // Keep reading to detect disconnection
        receive(on: connection)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            if let error = error {
                print("Connection error: \(error)")
                self?.removeConnection(connection)
                return
            }
            
            if isComplete {
                print("Connection closed by client")
                self?.removeConnection(connection)
                return
            }
            
            if let data = data, !data.isEmpty {
                // Handle incoming data if any (e.g. control signals)
                print("Received \(data.count) bytes")
            }
            
            // Continue receiving
            self?.receive(on: connection)
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        connection.cancel()
    }
    
    func send(data: Data) {
        for connection in connections {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Send error: \(error)")
                }
            })
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        isReady = false
        print("Server stopped")
    }
}
