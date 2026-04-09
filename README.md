# Local AI Realtime Assistant

A DIY AI glasses system with a native iOS companion app that bridges glasses
hardware (BLE) to an AI backend for real-time command processing.

## Repository contents

| Path | Description |
|---|---|
| `ios-companion/` | Native SwiftUI iOS companion app (iOS 16.0+) |
| `codemagic.yaml` | iOS-native Codemagic CI/CD workflow for the companion app |

## Quick start

See **[ios-companion/README.md](ios-companion/README.md)** for full setup instructions including:

- Opening the project in Xcode
- Configuring the AI backend endpoint
- Running a Codemagic build to TestFlight
- iOS limitations and background mode guidance

## Architecture overview

```
DIY Glasses Hardware
       │  BLE (CoreBluetooth)
       ▼
iOS Companion App  ──HTTPS──▶  AI Backend (your server)
       │                              │
       │◀─────── command JSON ────────┘
       │
  ActionHandler
  ├── tel:// → phone call (user confirms)
  ├── MPRemoteCommandCenter → media controls
  └── UIApplication.open → URLs / deep links
```

## Bundle ID

`com.barticekk.localairealtimeassistant.companion`

## Minimum iOS version

iOS 16.0
