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
        VStack(spacing: 0) {
            // Header - Compact
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Display")
                        .font(.system(size: 16, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(serverManager.isRunning ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(serverManager.isRunning ? "Streaming" : "Stopped")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Resolution
            VStack(alignment: .leading, spacing: 6) {
                Label("Resolution", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Picker("", selection: $serverManager.selectedResolution) {
                    ForEach(ServerManager.Resolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .onChange(of: serverManager.selectedResolution) { newValue in
                    serverManager.updateResolution(newValue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Frame Rate - Compact
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Frame Rate", systemImage: "speedometer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(serverManager.frameRate)) FPS")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $serverManager.frameRate, in: 30...120, step: 5)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Quality - Compact
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Quality", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(Int(serverManager.quality * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $serverManager.quality, in: 0.3...1.0, step: 0.05)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // USB Connection Status
            HStack {
                Label("USB Connection", systemImage: "cable.connector")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !serverManager.devices.isEmpty {
                    Text("Connected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    Text("No Device")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Actions - Compact
            VStack(spacing: 6) {
                Button(action: {
                    if serverManager.isRunning {
                        serverManager.stopServer()
                    } else {
                        serverManager.startServer()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: serverManager.isRunning ? "stop.fill" : "play.fill")
                        Text(serverManager.isRunning ? "Stop Server" : "Start Server")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(serverManager.isRunning ? Color.red : Color.green)
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
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
