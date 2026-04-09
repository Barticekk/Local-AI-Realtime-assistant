// CommandRouter.swift
// Receives AICommandResponse objects from AIBackendClient and dispatches
// them to the correct iOS-safe action handler.
//
// Routing table:
//   call_contact      → ActionHandler.initiateCall(target:)
//   music_play_pause  → ActionHandler.musicPlayPause()
//   music_next        → ActionHandler.musicNext()
//   music_previous    → ActionHandler.musicPrevious()
//   open_url          → ActionHandler.openURL(_:)
//   unknown           → logged, no action taken

import Foundation
import Combine

@MainActor
final class CommandRouter: ObservableObject {

    // ── Published state ──────────────────────────────────────────────────────

    /// The most recently routed command — shown in the companion UI.
    @Published private(set) var lastCommand: DisplayCommand?

    // ── Private ──────────────────────────────────────────────────────────────

    private let actionHandler = ActionHandler()
    private var cancellables  = Set<AnyCancellable>()

    // MARK: Init

    init() {}

    // MARK: Wiring

    /// Call once after all services are created to start receiving commands.
    /// - Parameter client: The AIBackendClient whose responses to consume.
    func subscribe(to client: AIBackendClient) {
        client.responseSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.route(response)
            }
            .store(in: &cancellables)
    }

    // MARK: Routing

    private func route(_ response: AICommandResponse) {
        lastCommand = DisplayCommand(from: response)

        switch response.action {
        case .callContact:
            actionHandler.initiateCall(target: response.target)

        case .musicPlayPause:
            actionHandler.musicPlayPause()

        case .musicNext:
            actionHandler.musicNext()

        case .musicPrevious:
            actionHandler.musicPrevious()

        case .openURL:
            if let urlString = response.target {
                actionHandler.openURL(urlString)
            }

        case .unknown:
            // Unrecognised action — safe to ignore.
            print("[CommandRouter] Received unknown action, ignoring.")
        }
    }
}
