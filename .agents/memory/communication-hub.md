---
name: Communication Hub feature
description: Full overview of the Hub tab added to LocalSend — chat, voice, video, remote files — architecture, routes, and known gotchas.
---

## Architecture

### New files
- `app/lib/model/hub/` — `hub_message.dart`, `hub_call_state.dart`, `hub_remote_file.dart`
- `app/lib/provider/hub/` — `hub_chat_provider.dart`, `hub_call_provider.dart`, `hub_files_provider.dart`
- `app/lib/provider/network/server/controller/hub_controller.dart` — HTTP route handlers + `HubIncomingBuffer` singleton
- `app/lib/pages/hub/` — `hub_chat_page.dart`, `hub_voice_call_page.dart`, `hub_video_call_page.dart`, `hub_remote_files_page.dart`
- `app/lib/pages/tabs/communication_hub_tab.dart` — device discovery cards + hub dashboard

### Wiring
- `HomeTab` enum has 4 values: receive, send, communicationHub, settings
- `HubController.installRoutes(router:)` called at line ~124 of `server_provider.dart`
- Routes: POST /hub/message, /hub/call/offer, /hub/call/answer, /hub/call/ice, /hub/call/hangup; GET /hub/files, /hub/file, /hub/info

### Key design decisions
- `HubIncomingBuffer` is a singleton that buffers inbound HTTP data until providers poll it (providers use `Timer.periodic`)
- Chat poll: every 2s; Call poll: every 500ms
- WebRTC via `flutter_webrtc: ^0.10.7`; LAN-only — STUN only for ICE (no TURN needed on LAN)
- Chat persistence: `SharedPreferences` key `hub_chat_<fingerprint>`

### Platform permissions added
- Android: `AndroidManifest.xml` — CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH permissions
- iOS: `Info.plist` — NSCameraUsageDescription, NSMicrophoneUsageDescription
- macOS: Both `DebugProfile.entitlements` and `Release.entitlements` — `com.apple.security.device.audio-input`, `com.apple.security.device.camera`

### Gotchas
- `StartSmartScan` is an `AsyncGlobalAction`, dispatched as `ref.global.dispatchAsync(StartSmartScan(forceLegacy: false))` — there is no `scanFacadeProvider`
- Do NOT use `with Refena` on StatelessWidget — use `context.read()` / `context.watch()` instead (see refena-stateless-ref.md)
- Do NOT override `dispose()` on Notifier subclasses — Notifier has no virtual dispose
- `context.global` is available as a BuildContext extension (confirmed in send_tab.dart line ~403)
