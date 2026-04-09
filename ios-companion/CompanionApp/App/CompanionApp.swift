// CompanionApp.swift
// Entry point for the AI Glasses Companion app.
// This is the SwiftUI @main struct — no UIKit AppDelegate required.

import SwiftUI

@main
struct CompanionApp: App {

    // Shared services injected into the SwiftUI environment so all views
    // can observe state changes without tight coupling.
    @StateObject private var bleManager:    BLEManager
    @StateObject private var backendClient: AIBackendClient
    @StateObject private var commandRouter: CommandRouter

    init() {
        let ble    = BLEManager()
        let client = AIBackendClient()
        let router = CommandRouter()
        // Wire the router to the client so it receives decoded responses.
        router.subscribe(to: client)
        _bleManager    = StateObject(wrappedValue: ble)
        _backendClient = StateObject(wrappedValue: client)
        _commandRouter = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
                .environmentObject(backendClient)
                .environmentObject(commandRouter)
        }
    }
}
