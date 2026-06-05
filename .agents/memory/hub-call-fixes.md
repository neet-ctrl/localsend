---
name: Hub voice call crash & silence fixes
description: Root causes and fixes for the four voice-call bugs (silence, black screen, no notification, no full-screen incoming call).
---

## Bug 1 — Silence / no audio
**Root cause**: `_setCallAudioMode(true)` was called after `getUserMedia()` and after ICE connected. Android must have `MODE_IN_COMMUNICATION` set BEFORE getUserMedia so hardware AEC/NS and earpiece routing engage from the start.  
Also `callerHttps` was set to `device.https` (the REMOTE's setting) instead of the caller's own https from `serverProvider?.https`. Wrong protocol in callee's answer-POST can silently drop the answer.  
**Fix**: Move `_setCallAudioMode(true)` to the very beginning of both `startCall()` and `acceptCall()`, before `getUserMedia`. Set `callerHttps = ref.read(serverProvider)?.https ?? false`.

## Bug 2 — Screen goes black on hangup (remote device)
**Root cause**: `peerConnection.close()` fires `onConnectionState(Disconnected)` synchronously, which called `endCall()` again (reentrant). Second `endCall()` ran `_cleanup()` while first was still inside `close()`, causing a Flutter engine crash / freeze → black screen.  
Also: the "End Call" button in hub_voice_call_page called BOTH `context.pop()` AND triggered the build-watcher pop on `ended` state → double-pop → navigator corruption.  
**Fix**:
- Add `_isEnding` bool guard in HubCallNotifier; `endCall()` returns early if already running.
- In `_cleanup()`, set `_peerConnection = null` BEFORE calling `pc.close()` so the callback fires on null ref and the guard catches any re-entry.
- Remove direct `context.pop()` from the End Call button; let `build()` handle pop when state reaches `ended`.
- Added `FLAG_KEEP_SCREEN_ON` toggled in the existing `setCallAudioMode` Kotlin handler.

## Bug 3 — No incoming call notification when backgrounded
**Root cause**: Call detection only happened in Flutter's poll loop watched by `home_page.dart`. Nothing showed to the user if the app was not in foreground.  
**Fix**: Added `showIncomingCallNotification(callerName, callType)` / `dismissCallNotification()` MethodChannel methods in MainActivity. Flutter calls `showIncomingCallNotification` from the poll loop when state becomes `incoming`. Creates a `IMPORTANCE_HIGH` notification channel (`localsend_incoming_call`) with Accept/Decline PendingIntent actions.

## Bug 4 — Full-screen incoming call only inside app
**Root cause**: No `fullScreenIntent` on the notification; activity lacked lock-screen flags.  
**Fix**:
- Added `USE_FULL_SCREEN_INTENT` permission to AndroidManifest.
- `showIncomingCallNotification` sets `fullScreenIntent` on the notification builder.
- Added `android:showWhenLocked="true"` and `android:turnScreenOn="true"` to MainActivity in manifest.
- `onNewIntent()` in MainActivity reads `callAction` intent extra and fires `notificationCallAction` MethodChannel method back to Flutter; Flutter's `_platform.setMethodCallHandler` calls `acceptCall()` or `rejectCall()`.

## RTCVideoRenderer lifecycle
- Do NOT dispose renderers in `_cleanup()`. They are notifier-lifetime objects reused across calls. Disposing them between calls causes "initialized on disposed renderer" crashes on the next call.
- Initialize once via `_renderersInitialized` flag; only clear `srcObject` in cleanup.

## Key files
- `app/lib/provider/hub/hub_call_provider.dart` — all call logic, guards, notification calls
- `app/lib/pages/hub/hub_voice_call_page.dart` — removed double-pop from End Call button
- `app/android/app/src/main/kotlin/org/localsend/localsend_app/MainActivity.kt` — notification methods, onNewIntent handler
- `app/android/app/src/main/AndroidManifest.xml` — USE_FULL_SCREEN_INTENT, showWhenLocked, turnScreenOn
