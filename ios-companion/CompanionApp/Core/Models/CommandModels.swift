// CommandModels.swift
// Typed models exchanged between the AI backend and the iOS action layer.
//
// The backend should return JSON that conforms to AICommandResponse.
// Example payload:
//   {
//     "action": "call_contact",
//     "target": "John",
//     "payload": null
//   }

import Foundation

// MARK: - Outbound request

/// Sent from the iOS app to the AI backend.
struct AICommandRequest: Encodable {
    /// Raw transcript or intent text captured from the glasses/mic.
    let text: String
    /// Optional session context.
    let sessionID: String?
}

// MARK: - Inbound response

/// Top-level response envelope from the AI backend.
struct AICommandResponse: Decodable {
    let action: AIAction
    /// Human-readable target, e.g. contact name, URL string, search query.
    let target: String?
    /// Additional free-form payload for future extension.
    let payload: String?
}

// MARK: - Action type

/// Every action the AI backend can request the companion app to perform.
/// Map new capabilities here and add a corresponding handler in ActionRouter.
enum AIAction: String, Decodable {
    case callContact      = "call_contact"
    case musicPlayPause   = "music_play_pause"
    case musicNext        = "music_next"
    case musicPrevious    = "music_previous"
    case openURL          = "open_url"
    /// Fallback for unknown future actions — handled gracefully.
    case unknown

    /// Custom decoder so that unrecognised backend strings map to `.unknown`
    /// instead of throwing a DecodingError.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AIAction(rawValue: raw) ?? .unknown
    }
}

// MARK: - View model (for UI display)

/// Lightweight value used by ContentView / CommandRouter to display last command.
struct DisplayCommand {
    let action: String
    let target: String?
    let rawPayload: String?

    init(from response: AICommandResponse) {
        self.action     = response.action.rawValue
        self.target     = response.target
        self.rawPayload = response.payload
    }
}
