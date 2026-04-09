// AIBackendClient.swift
// Sends intent/text requests to the configurable AI backend and decodes
// typed AICommandResponse objects.
//
// Configuration:
//   • Set the backend base URL in Settings (stored in UserDefaults under "backendURL").
//   • Default endpoint is AIBackendClient.defaultEndpoint (update before shipping).
//
// API contract (backend must implement):
//   POST /command
//   Content-Type: application/json
//   Body: { "text": "...", "sessionID": "..." }
//   Response: AICommandResponse JSON

import Foundation
import Combine

@MainActor
final class AIBackendClient: ObservableObject {

    // MARK: Configuration

    static let defaultEndpoint = "https://your-backend.example.com"  // TODO: replace

    /// Live endpoint read from UserDefaults (editable in SettingsView).
    var endpointURL: String {
        UserDefaults.standard.string(forKey: "backendURL") ?? Self.defaultEndpoint
    }

    // ── Published state ──────────────────────────────────────────────────────

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var statusDescription: String = "Idle"

    // ── Response passthrough ─────────────────────────────────────────────────

    /// Emits decoded responses; subscribe in CommandRouter.
    let responseSubject = PassthroughSubject<AICommandResponse, Never>()

    // ── Private ──────────────────────────────────────────────────────────────

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Public API

    /// Send a text/intent string to the backend and publish the decoded command.
    /// - Parameter text: Raw transcript or structured intent from glasses/mic.
    func send(text: String, sessionID: String? = nil) {
        let request = AICommandRequest(text: text, sessionID: sessionID)

        guard
            let baseURL = URL(string: endpointURL),
            let url = URL(string: "/command", relativeTo: baseURL)
        else {
            statusDescription = "Invalid endpoint URL"
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            statusDescription = "Encoding error: \(error.localizedDescription)"
            return
        }

        statusDescription = "Sending…"

        Task {
            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run { statusDescription = "Invalid response" }
                    return
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        statusDescription = "HTTP \(httpResponse.statusCode)"
                        isConnected = false
                    }
                    return
                }

                let commandResponse = try decoder.decode(AICommandResponse.self, from: data)
                await MainActor.run {
                    isConnected = true
                    statusDescription = "OK"
                    responseSubject.send(commandResponse)
                }

            } catch {
                await MainActor.run {
                    isConnected = false
                    statusDescription = error.localizedDescription
                }
            }
        }
    }
}
