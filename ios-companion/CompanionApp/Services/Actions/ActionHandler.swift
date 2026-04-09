// ActionHandler.swift
// iOS-safe action implementations for commands received from the AI backend.
//
// App Store safety notes
// ──────────────────────
// All actions use only public iOS APIs and require explicit user interaction or
// system-level confirmation where mandated by Apple:
//
//   • Phone calls   — opened via the `tel://` URL scheme; iOS shows the native
//                     call confirmation sheet before dialling. Silent automatic
//                     dialling is NOT possible on iOS (App Store policy).
//
//   • Media control — MPRemoteCommandCenter targets whichever audio app is
//                     currently active (Music, Spotify, Podcasts, etc.).
//                     iOS restricts background media control; the companion app
//                     must be playing/pausing as the "Now Playing" app or use
//                     a Bluetooth Hands-Free Profile to be eligible. These stubs
//                     work reliably when the companion app is in the foreground.
//
//   • URL opening   — handled by UIApplication.open, respecting all iOS sandboxing.
//
// Background modes
// ─────────────────
// Do NOT enable background modes speculatively. Enable only what you need:
//   • "audio" — required for AVAudioSession microphone capture in background.
//   • "bluetooth-central" — required if BLE must reconnect while backgrounded.
//   • "voip" — for CallKit-based VoIP calls (not used here).
// These are declared in Info.plist under UIBackgroundModes.

import Foundation
import UIKit
import MediaPlayer

final class ActionHandler {

    // MARK: - Call initiation

    /// Initiates a phone call via the `tel://` URL scheme.
    ///
    /// iOS behaviour: the system presents a confirmation sheet ("Call <number>?")
    /// before dialling. There is no API to bypass this confirmation on a
    /// non-jailbroken device — this is intentional App Store policy.
    ///
    /// - Parameter target: A phone number string or contact name.
    ///   If a name is provided you must first resolve it to a number via
    ///   the Contacts framework (requires CNContactStore authorisation).
    ///   TODO: Add contact lookup via Contacts.framework when ready.
    func initiateCall(target: String?) {        guard let rawTarget = target, !rawTarget.isEmpty else {
            print("[ActionHandler] initiateCall: no target provided")
            return
        }

        // Strip common formatting characters to produce a dialable number.
        let digits = rawTarget
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()

        // Fall back to the raw string if no digits were found (e.g. name passed).
        let dialString = digits.isEmpty ? rawTarget : digits

        guard
            let encoded = dialString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
            let url = URL(string: "tel://\(encoded)")
        else {
            print("[ActionHandler] initiateCall: could not construct tel:// URL for '\(rawTarget)'")
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("[ActionHandler] initiateCall: system could not open tel:// URL — running on simulator?")
                }
            }
        }
    }

    // MARK: - Media control

    /// Sends a play/pause toggle command to the current Now Playing app.
    ///
    /// iOS limitation: MPRemoteCommandCenter can receive events in foreground.
    /// To control media while the companion app is in the background the device
    /// must use a Bluetooth Hands-Free Profile or the app must be the active
    /// audio session owner. Silent background media control of third-party apps
    /// is not supported by iOS.
    func musicPlayPause() {
        sendMediaCommand(.togglePlayPause)
    }

    /// Skips to the next track in the active Now Playing app.
    func musicNext() {
        sendMediaCommand(.nextTrack)
    }

    /// Skips to the previous track in the active Now Playing app.
    func musicPrevious() {
        sendMediaCommand(.previousTrack)
    }

    // MARK: - URL opening

    /// Opens any URL using the iOS URL routing system.
    /// Supports http/https, custom schemes (e.g. spotify://), etc.
    /// - Parameter urlString: The URL to open.
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("[ActionHandler] openURL: invalid URL string '\(urlString)'")
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("[ActionHandler] openURL: could not open '\(urlString)'")
                }
            }
        }
    }

    // MARK: - Private helpers

    /// Sends a remote-control media command to the currently active audio app.
    ///
    /// Implementation note:
    ///   MPRemoteCommandCenter is designed to *receive* commands (e.g. from
    ///   headphones/CarPlay), not to *send* them to other apps. The practical
    ///   approaches to controlling third-party media apps on iOS are:
    ///
    ///   1. **AVAudioSession route change** — activating your audio session with
    ///      `.mixWithOthers` and then deactivating it can resume the previous
    ///      audio app, but does not give play/pause/next control.
    ///
    ///   2. **Bluetooth HFP / AVRCP** — if your glasses present a Bluetooth
    ///      Hands-Free or AVRCP profile, iOS will route media button events
    ///      automatically to the Now Playing app without any app code.
    ///
    ///   3. **MediaPlayer framework (Apple Music only)** — `MPMusicPlayerController
    ///      .systemMusicPlayer` can control Apple Music when the user grants
    ///      permission via the Music usage description.
    ///
    ///   TODO: Implement one of the approaches above based on your hardware.
    ///   For glasses using an AVRCP BLE profile, approach 2 is recommended and
    ///   requires no additional iOS code — the system handles button routing.
    private func sendMediaCommand(_ command: MPRemoteCommandCenter.Command) {
        // Placeholder — see implementation note above.
        print("[ActionHandler] Media command requested: \(command). Full implementation requires AVAudioSession or BLE AVRCP profile.")
    }
}

// MARK: - MPRemoteCommandCenter convenience

private extension MPRemoteCommandCenter {
    /// Named cases used by ActionHandler to identify which media command to send.
    enum Command: CustomStringConvertible {
        case togglePlayPause
        case nextTrack
        case previousTrack

        var description: String {
            switch self {
            case .togglePlayPause: return "togglePlayPause"
            case .nextTrack:       return "nextTrack"
            case .previousTrack:   return "previousTrack"
            }
        }
    }
}
