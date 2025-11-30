import SwiftUI
import AppKit

@main
struct MacApp: App {
    @StateObject private var serverManager = ServerManager()
    
    var body: some Scene {
        MenuBarExtra("MacDisplay", systemImage: "display") {
            ContentView(serverManager: serverManager)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @ObservedObject var serverManager: ServerManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "display.2")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("MacDisplay")
                        .font(.headline)
                    Text(serverManager.isRunning ? "Running" : "Stopped")
                        .font(.subheadline)
                        .foregroundStyle(serverManager.isRunning ? .green : .red)
                }
                Spacer()
            }
            .padding(.top)
            
            Divider()
            
            // Controls
            VStack(alignment: .leading, spacing: 12) {
                // Resolution
                HStack {
                    Text("Resolution")
                    Spacer()
                    Picker("", selection: $serverManager.selectedResolution) {
                        ForEach(ServerManager.Resolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: serverManager.selectedResolution) { newValue in
                        serverManager.updateResolution(newValue)
                    }
                }
                
                // Quality
                VStack(alignment: .leading) {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Text("\(Int(serverManager.quality * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $serverManager.quality, in: 0.1...1.0)
                }
                
                // USB Status
                HStack {
                    Text("USB Connection")
                    Spacer()
                    if !serverManager.devices.isEmpty {
                        Text("Connected")
                            .foregroundStyle(.green)
                    } else {
                        Text("No Device")
                            .foregroundStyle(.orange)
                    }
                }
                
                Divider()
                
                // Settings
                Toggle("Launch at Login", isOn: $serverManager.launchAtLogin)
            }
            
            Divider()
            
            // Actions
            Button(action: {
                if serverManager.isRunning {
                    serverManager.stopServer()
                } else {
                    serverManager.startServer()
                }
            }) {
                HStack {
                    Image(systemName: serverManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                    Text(serverManager.isRunning ? "Stop Server" : "Start Server")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(serverManager.isRunning ? .red : .green)
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 300)
        .alert("Error", isPresented: $serverManager.showAlert) {
            if let msg = serverManager.errorMessage, msg.contains("permission") {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(serverManager.errorMessage ?? "Unknown error")
        }
    }
}
