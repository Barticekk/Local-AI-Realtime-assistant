// ContentView.swift
// Main companion status screen shown when the app is open.
// Displays BLE connection state, backend reachability, and the last command
// received from the AI backend — all useful for development and debugging.

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var bleManager:    BLEManager
    @EnvironmentObject private var backendClient: AIBackendClient
    @EnvironmentObject private var commandRouter: CommandRouter

    var body: some View {
        NavigationStack {
            List {
                // ── BLE status panel ──────────────────────────────────────
                Section("Glasses (BLE)") {
                    StatusRow(
                        label: "Bluetooth",
                        value: bleManager.bluetoothStateDescription,
                        color: bleManager.isReady ? .green : .orange
                    )
                    StatusRow(
                        label: "Glasses connected",
                        value: bleManager.connectedPeripheral?.name ?? "None",
                        color: bleManager.connectedPeripheral != nil ? .green : .secondary
                    )
                    StatusRow(
                        label: "Discovered devices",
                        value: "\(bleManager.discoveredPeripherals.count)",
                        color: .primary
                    )

                    HStack {
                        if bleManager.isScanning {
                            Button("Stop scan", role: .destructive) {
                                bleManager.stopScanning()
                            }
                        } else {
                            Button("Start scan") {
                                bleManager.startScanning()
                            }
                            .disabled(!bleManager.isReady)
                        }
                    }
                }

                // ── Backend status panel ──────────────────────────────────
                Section("AI Backend") {
                    StatusRow(
                        label: "Endpoint",
                        value: backendClient.endpointURL,
                        color: .primary
                    )
                    StatusRow(
                        label: "Status",
                        value: backendClient.statusDescription,
                        color: backendClient.isConnected ? .green : .orange
                    )
                }

                // ── Last command panel ────────────────────────────────────
                Section("Last command") {
                    if let cmd = commandRouter.lastCommand {
                        StatusRow(label: "Action",  value: cmd.action,           color: .blue)
                        StatusRow(label: "Target",  value: cmd.target ?? "—",    color: .secondary)
                        StatusRow(label: "Payload", value: cmd.rawPayload ?? "—", color: .secondary)
                    } else {
                        Text("No command received yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Settings") {
                        SettingsView()
                    }
                }
            }
        }
    }
}

// MARK: - Reusable status row

private struct StatusRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Settings view placeholder

struct SettingsView: View {
    /// Backend base URL editable at runtime for development.
    @AppStorage("backendURL") private var backendURL = AIBackendClient.defaultEndpoint

    var body: some View {
        Form {
            Section("Backend") {
                TextField("Base URL", text: $backendURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section {
                Text("Changes take effect on the next request.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .environmentObject(BLEManager())
        .environmentObject(AIBackendClient())
        .environmentObject(CommandRouter())
}
