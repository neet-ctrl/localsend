---
name: Communication Hub feature
description: Full overview of the Hub tab added to LocalSend — chat, voice, video, remote files — architecture, routes, ringtone, and known gotchas.
---

## Architecture

### New files
- `app/lib/model/hub/` — `hub_message.dart`, `hub_call_state.dart`, `hub_remote_file.dart`
- `app/lib/provider/hub/` — `hub_chat_provider.dart`, `hub_call_provider.dart`, `hub_files_provider.dart`, `hub_ringtone_service.dart`
- `app/lib/provider/network/server/controller/hub_controller.dart` — HTTP route handlers + `HubIncomingBuffer` singleton
- `app/lib/pages/hub/` — `hub_chat_page.dart`, `hub_voice_call_page.dart`, `hub_video_call_page.dart`, `hub_remote_files_page.dart`
- `app/lib/pages/tabs/communication_hub_tab.dart` — device discovery cards + hub dashboard

### Wiring
- `HomeTab` enum has 4 values: receive, send, communicationHub, settings
- `HubController.installRoutes(router:)` called at line ~124 of `server_provider.dart`
- Routes: POST /hub/message, /hub/call/offer, /hub/call/answer, /hub/call/ice, /hub/call/hangup; GET /hub/files, /hub/file, /hub/info
- `home_page.dart` watches `hubCallProvider` + `hubChatProvider` in build; dispatches full-screen overlay via `Navigator.of(context, rootNavigator: true)` on incoming call

### Key design decisions
- `HubIncomingBuffer` is a singleton that buffers inbound HTTP data until providers poll it (providers use `Timer.periodic`)
- Chat poll: every 2s; Call poll: every 500ms
- WebRTC via `flutter_webrtc: ^0.10.7`; **LAN-only, zero ICE servers** — `iceServers: []` in peer connection config (fully offline, no internet needed)
- Chat persistence: `SharedPreferences` key `hub_chat_<fingerprint>`
- Ringtone: `HubRingtoneService` singleton wraps `flutter_ringtone_player ^4.0.0`; started in `hub_call_provider` poll when incoming detected, stopped on accept/reject/end
- Chat notification: glassmorphic SnackBar shown from `home_page.dart` when unread count rises and user is not on Hub tab; 3s warm-up delay prevents false alerts on startup
- Incoming call full-screen overlay: `Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(...))` — covers all tabs; `_callOverlayShown` flag prevents duplicates

### Platform permissions added
- Android: CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH, FOREGROUND_SERVICE, POST_NOTIFICATIONS, **VIBRATE** (for ringtone)
- iOS: NSCameraUsageDescription, NSMicrophoneUsageDescription
- macOS: `com.apple.security.device.audio-input`, `com.apple.security.device.camera` in both Debug + Release entitlements

### Gotchas
- `StartSmartScan` is an `AsyncGlobalAction`, dispatched as `ref.global.dispatchAsync(StartSmartScan(forceLegacy: false))` — there is no `scanFacadeProvider`
- Do NOT use `with Refena` on StatelessWidget — use `context.read()` / `context.watch()` instead (see refena-stateless-ref.md)
- Do NOT override `dispose()` on Notifier subclasses — Notifier has no virtual dispose
- `context.global` is available as a BuildContext extension (confirmed in send_tab.dart line ~403)
- `_handleCallState` and `_handleChatState` are called inside `build()` — they only mutate plain instance vars (not setState) and schedule side-effects via `addPostFrameCallback`, which is safe
