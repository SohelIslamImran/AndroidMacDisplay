import Foundation
import Combine
import CoreMedia
import ServiceManagement

@MainActor
class ServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var isConnected = false
    @Published var devices: [String] = []
    @Published var errorMessage: String?
    @Published var showAlert = false
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            // Prevent infinite loop if setting initial value
            if launchAtLogin == oldValue { return }
            
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                    print("Registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("Unregistered from launch at login")
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
                // Revert if failed (optional, might cause loop if not careful)
            }
        }
    }

    @Published var selectedResolution: Resolution = .p720
    @Published var frameRate: Double = 60 // 30-120 FPS
    @Published var quality: Double = 0.8 { // Default 80% for balanced performance
        didSet {
            encoder?.quality = quality
        }
    }
    
    enum Resolution: String, CaseIterable, Identifiable {
        case p720 = "720p"
        case p1080 = "1080p"
        case native = "Native"
        
        var id: String { self.rawValue }
        
        var size: (width: Int, height: Int)? {
            switch self {
            case .p720: return (1280, 720)
            case .p1080: return (1920, 1080)
            case .native: return nil
            }
        }
    }
    
    private let usbManager = USBManager()
    private let tcpServer = TCPServer()
    private let screenCapture = ScreenCapture()
    private var encoder: VideoEncoder?
    private var lastEncodedFrame: Data?
    
    init() {
        // Initialize Launch at Login state
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        // Auto-start server
        // We call this in a Task to avoid blocking init, though startServer handles most things asynchronously anyway.
        // But since startServer checks !isRunning, and we just inited, it's safe.
        // However, calling method on 'self' before full init is tricky in Swift if not careful.
        // But 'self' is fully initialized after property sets.
        
        // Monitor devices periodically using Task instead of Timer
        Task { [weak self] in
            while let self = self {
                await self.checkDevices()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        
        // Auto Start
        startServer()
    }
    
    func startServer() {
        guard !isRunning else { return }
        
        print("Starting Server...")
        errorMessage = nil
        
        // Setup TCP Connection Handler for immediate frame update
        tcpServer.onNewConnection = { [weak self] in
            Task { @MainActor [weak self] in
                // Slight delay to ensure client is ready to receive
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                
                print("Client ready. Sending immediate frame update.")
                if let self = self, let data = self.lastEncodedFrame {
                    self.tcpServer.send(data: data)
                } else {
                    print("No last frame available to send.")
                }
            }
        }
        
        // 1. Start TCP
        if !tcpServer.start() {
            print("Port 9090 might be in use. Attempting to free it...")
            if killProcessUsingPort(port: 9090) {
                // Wait a bit for the OS to release the port
                Thread.sleep(forTimeInterval: 0.5)
                if !tcpServer.start() {
                     print("Failed to start TCP server after killing old process")
                     errorMessage = "Failed to bind to port 9090 even after cleanup."
                     showAlert = true
                     return
                }
            } else {
                print("Failed to start TCP server")
                errorMessage = "Failed to bind to port 9090. It might be in use."
                showAlert = true
                return
            }
        }
        
        // 2. Start USB (offload blocking work)
        // We now start the continuous monitoring loop instead of a one-off check.
        // This ensures that if the device is plugged in AFTER the server starts,
        // or if the connection is reset, the adb reverse tunnel is re-established.
        usbManager.startMonitoring()
        
        // 3. Start Capture
        Task {
            setupCapture()
            do {
                try await screenCapture.startCapture()
                isRunning = true
            } catch {
                print("Capture failed: \(error)")
                errorMessage = error.localizedDescription
                showAlert = true
                // Cleanup
                tcpServer.stop() // Ensure we implement this or just ignore for now
            }
        }
    }
    
    private func killProcessUsingPort(port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["lsof", "-t", "-i", ":\(port)"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
                return false 
            }
            
            let pids = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var killedAny = false
            for pidStr in pids {
                if let pid = Int(pidStr) {
                    if pid == ProcessInfo.processInfo.processIdentifier {
                        continue 
                    }
                    print("Killing process \(pid) on port \(port)")
                    let killTask = Process()
                    killTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    killTask.arguments = ["kill", "-9", "\(pid)"]
                    try? killTask.run()
                    killTask.waitUntilExit()
                    killedAny = true
                }
            }
            return killedAny
        } catch {
            print("Failed to kill process: \(error)")
            return false
        }
    }
    
    func stopServer() {
        guard isRunning else { return }
        
        print("Stopping Server...")
        screenCapture.stopCapture()
        tcpServer.stop()
        usbManager.stopMonitoring()
        isRunning = false
    }
    
    private func setupCapture() {
        screenCapture.setResolution(width: selectedResolution.size?.width, height: selectedResolution.size?.height)
        screenCapture.setFrameRate(fps: Int(frameRate))
        
        screenCapture.onFrame = { [weak self] sampleBuffer in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.encoder == nil {
                    self.encoder = VideoEncoder()
                    self.encoder?.quality = self.quality
                    self.encoder?.onEncodedData = { [weak self] data in
                        self?.lastEncodedFrame = data
                        self?.tcpServer.send(data: data)
                    }
                }
                self.encoder?.encode(sampleBuffer)
            }
        }
    }
    
    private func checkDevices() async {
        // Offload blocking check
        let hasDevice = await Task.detached { [usbManager] in
            return usbManager.checkDevices()
        }.value
        
        if hasDevice {
            if !devices.contains("Connected Device") {
                devices = ["Connected Device"]
            }
        } else {
            devices = []
        }
    }
    
    func updateResolution(_ res: Resolution) {
        selectedResolution = res
        if isRunning {
            // Restart capture to apply resolution
            Task {
                screenCapture.stopCapture()
                setupCapture()
                do {
                    try await screenCapture.startCapture()
                } catch {
                    print("Failed to update resolution: \(error)")
                    errorMessage = error.localizedDescription
                    showAlert = true
                    isRunning = false
                }
            }
        }
    }
}
