---
name: Communication Hub feature
description: Full overview of the Hub tab added to LocalSend — chat, voice, video, remote files — architecture, routes, ringtone, and known gotchas.
---

## Architecture

### New files
- `app/lib/model/hub/` — `hub_message.dart`, `hub_call_state.dart`, `hub_remote_file.dart`
- `app/lib/provider/hub/` — `hub_chat_provider.dart`, `hub_call_provider.dart`, `hub_files_provider.dart`, `hub_device_history_provider.dart`, `hub_ringtone_service.dart`, `hub_foreground_service.dart`
- `app/android/app/src/main/kotlin/.../HubForegroundService.kt` — native Android foreground service
- `app/android/app/src/main/kotlin/.../BootReceiver.kt` — starts service on boot
- `app/lib/provider/network/server/controller/hub_controller.dart` — HTTP route handlers + `HubIncomingBuffer` singleton
- `app/lib/pages/hub/` — `hub_chat_page.dart`, `hub_voice_call_page.dart`, `hub_video_call_page.dart`, `hub_remote_files_page.dart`
- `app/lib/pages/tabs/communication_hub_tab.dart` — device discovery cards + hub dashboard

### Wiring
- `HomeTab` enum has 4 values: receive, send, communicationHub, settings
- `HubController.installRoutes(router:)` called at line ~124 of `server_provider.dart`
- Routes: POST /hub/message, /hub/call/offer, /hub/call/answer, /hub/call/ice, /hub/call/hangup; GET /hub/files, /hub/file, /hub/info
- `home_page.dart` watches `hubCallProvider` + `hubChatProvider` in build; dispatches full-screen overlay on incoming call

### Key design decisions
- `HubIncomingBuffer` singleton buffers inbound HTTP data; providers poll it (Timer.periodic)
- Chat poll: every 2s; Call poll: every 500ms
- WebRTC via `flutter_webrtc`; **LAN-only, zero ICE servers** — `iceServers: []`
- Chat persistence: `SharedPreferences` key `hub_chat_<fingerprint>`
- Device history persistence: `SharedPreferences` key `hub_device_history_v1`

## Critical bugs fixed (session)

### ICE candidate buffering — root cause of no audio/video
Candidates arriving BEFORE `setRemoteDescription` were silently caught and dropped.
Fix: `HubCallNotifier` has `_pendingCandidates` list + `_remoteDescSet` flag.
- Candidates added during polling go to `_pendingCandidates` if `!_remoteDescSet`
- After every `setRemoteDescription`, call `_flushPendingCandidates()`
- Poll loop drains ICE candidates in `incoming` state too (candidates arrive before accept)

### Speakerphone — no audio on mobile
`Helper.setSpeakerphoneOn(bool)` from `flutter_webrtc` MUST be called.
Setting state flag alone does nothing. Called in `acceptCall()`, `_handleRemoteAnswer()`, `toggleSpeaker()`.
Default ON when call becomes active so both sides hear each other.

### Remote file browser root path — errno=13
`Directory('/')` fails on Android. Fix applied in two places:
1. Client: `hub_files_provider.dart openDevice()` starts at `/storage/emulated/0` on Android
2. Server: `hub_controller.dart _handleFileList` maps requested `/` → `/storage/emulated/0` on Android

### Device history — offline chat access
`HubDeviceHistoryNotifier` persists `Map<fingerprint, HubHistoryDevice>` to SharedPreferences.
`sawDevice()` is **throttled** (skips update if same IP seen within 60s) — prevents rebuild loops when called inside `build()`.
Hub tab shows offline history section with Chat + Forget buttons.

### File download in chat — receiver couldn't save received files
`HubMessage` carries `senderIp`, `senderPort`, `senderHttps` (server injects `senderIp` from HTTP connection).
Receiver chat bubble shows Download button → `hubFilesProvider.downloadChatFile()` → `GET /hub/file?path=<content>`.

### hasRemoteTrack — force RTCVideoView rebuild when remote track arrives
`HubCallState.hasRemoteTrack` set to true in `onTrack` callback to trigger a state change,
which causes the widget tree to rebuild so RTCVideoView can show the newly-received stream.

## HubMessage model fields
id, senderFingerprint, senderAlias, content, timestamp, type, filePath, fileName, fileSize, senderIp, senderPort, senderHttps, delivered, read.

## HubCallState fields
status, type, remoteDevice, startTime, isMuted, isSpeakerOn, isVideoEnabled, isOnHold, **hasRemoteTrack**, incomingSdp, incomingSdpType, errorMessage.
`copyWith` supports `clearIncoming: true` (nulls incomingSdp/incomingSdpType) and `clearError: true`.

## Gotchas
- `StartSmartScan` dispatched as `ref.global.dispatchAsync(StartSmartScan(forceLegacy: false))`
- Do NOT use `with Refena` on StatelessWidget — use `context.read()` / `context.watch()`
- Do NOT override `dispose()` on Notifier subclasses
- `request.ip` extension available via import `simple_server.dart` (defined in `RequestExt on HttpRequest`)
- ALL `Permission.storage` replaced with `Permission.manageExternalStorage` throughout codebase
