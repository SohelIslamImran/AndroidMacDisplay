import Foundation

class USBManager: @unchecked Sendable {
    private let adbPath = "/opt/homebrew/bin/adb" // Assumption: User has ADB installed via Homebrew. We might need to find it dynamically.

    func startMonitoring() {
        print("Starting USB Monitor...")
        Task {
            while true {
                if let deviceId = getFirstDevice() {
                    // We found a device. Let's try to reverse.
                    // We can optimize this by checking if it's already done, but running it again is harmless and ensures it works.
                    // To avoid spamming logs, we can check if it changed or just run it.
                    // For simplicity, let's run it.
                    runADBReverse(deviceId: deviceId)
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }

    func startADBReverse() {
        // Initial check
        if let deviceId = getFirstDevice() {
            runADBReverse(deviceId: deviceId)
        }
    }
    
    private func runADBReverse(deviceId: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["adb", "-s", deviceId, "reverse", "tcp:8000", "tcp:8000"]
        
        do {
            try task.run()
            task.waitUntilExit()
            // Silence success logs to avoid spam in loop
            if task.terminationStatus != 0 {
                print("ADB Reverse failed for \(deviceId)")
            }
        } catch {
            print("Failed to run ADB: \(error)")
        }
    }
    
    func checkDevices() -> Bool {
        return getFirstDevice() != nil
    }
    
    private func getFirstDevice() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["adb", "devices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    // Skip "List of devices attached" and empty lines
                    if line.contains("List of devices") || line.isEmpty { continue }
                    
                    // Format: "deviceId\tdevice"
                    let parts = line.components(separatedBy: .whitespaces)
                    if let id = parts.first, !id.isEmpty {
                        return id
                    }
                }
            }
        } catch {
            print("Failed to check devices: \(error)")
        }
        return nil
    }
}
