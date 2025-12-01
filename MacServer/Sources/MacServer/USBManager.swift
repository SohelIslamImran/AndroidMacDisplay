import Foundation

class USBManager: @unchecked Sendable {

    private func getADBPath() -> String {
        let possiblePaths = [
            "/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
            "/usr/bin/adb"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "adb" // Fallback to PATH look up if absolute paths fail
    }

    private var monitorTask: Task<Void, Never>?

    func startMonitoring() {
        print("Starting USB Monitor...")
        stopMonitoring() // Cancel existing if any

        monitorTask = Task {
            while !Task.isCancelled {
                if let deviceId = getFirstDevice() {
                    // Always re-apply reverse to ensure persistence across unplugs/restarts of ADB
                    runADBReverse(deviceId: deviceId)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second check
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func startADBReverse() {
        if let deviceId = getFirstDevice() {
            runADBReverse(deviceId: deviceId)
        }
    }

    private func runADBReverse(deviceId: String) {
        let adbPath = getADBPath()
        let task = Process()

        if adbPath == "adb" {
             task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
             task.arguments = ["adb", "-s", deviceId, "reverse", "tcp:9090", "tcp:9090"]
        } else {
             task.executableURL = URL(fileURLWithPath: adbPath)
             task.arguments = ["-s", deviceId, "reverse", "tcp:9090", "tcp:9090"]
        }

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                print("ADB Reverse failed for \(deviceId)")
            } else {
                print("ADB Reverse success for \(deviceId)")
            }
        } catch {
            print("Failed to run ADB: \(error)")
        }
    }

    func checkDevices() -> Bool {
        return getFirstDevice() != nil
    }

    private func getFirstDevice() -> String? {
        let adbPath = getADBPath()
        let task = Process()

        if adbPath == "adb" {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["adb", "devices"]
        } else {
            task.executableURL = URL(fileURLWithPath: adbPath)
            task.arguments = ["devices"]
        }

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("List of devices") || line.isEmpty { continue }

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
