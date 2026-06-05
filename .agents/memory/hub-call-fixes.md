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

## Bug 5 — ICE gathering race condition (silence AND no video)
**Root cause**: `_waitForGatheringComplete` set `onIceGatheringState` AFTER calling `setLocalDescription`. On a fast LAN the ICE gathering completes in milliseconds — the "complete" event fires before the listener is attached, is missed, and the code waits the full 10-second timeout on EVERY call. This caused ~10s of silence/black screen before media could flow.  
**Fix**: Renamed to `_setLocalDescriptionAndGather`. Handler is attached BEFORE `setLocalDescription` is called — no race. Timeout reduced to 6s as a safety net only.  
**Rule**: Always set WebRTC event handlers before the action that triggers them.

## Bug 6 — Video call page double-pop
**Root cause**: Same as voice call (Bug 2). The End button in `hub_video_call_page.dart` called `callNotifier.endCall(); context.pop()` while `build()` also popped on `ended` state.  
**Fix**: Removed `context.pop()` from End button; state-based pop handles navigation.

## Bug 8 (CRITICAL) — onTrack empty streams → no remote audio/video
**Root cause**: `flutter_webrtc` frequently fires `onTrack` with `event.streams` empty; the actual track is in `event.track` only. The old code did `if (event.streams.isNotEmpty)` → skipped entirely → renderer never got a source → other phone shows black/silence.  
**Fix**: Pre-create `_remoteStream = await createLocalMediaStream(...)` in both `startCall` and `acceptCall` BEFORE `_createPeerConnection`. In `onTrack`: if streams present use first, else add `event.track` to `_remoteStream` and set renderer. Also disposes `_remoteStream` in `_cleanup`.  
**Rule**: Always pre-create a remote stream container; never rely solely on `event.streams.isNotEmpty`.

## Bug 9 — toggleVideo is a no-op (double negation cancels out)
**Root cause**: `final disabled = !state.isVideoEnabled` then `t.enabled = !disabled` → the two negations cancel → track state never changes.  
**Fix**: `final nowEnabled = !state.isVideoEnabled; t.enabled = nowEnabled;` — single clean flip.

## Bug 7 — No chat message notifications
**Root cause**: No system notification was fired when new Hub messages arrived. Only an in-app banner was shown (home_page.dart), invisible when backgrounded.  
**Fix**: `hub_chat_provider.dart` poll loop calls `_showChatNotification(senderAlias, content, type)` for each genuinely new message. `MainActivity.kt` handles `showChatNotification` MethodChannel call and fires a per-sender heads-up notification (IMPORTANCE_HIGH, `CATEGORY_MESSAGE`). Notification IDs are unique per sender name so messages from different people don't overwrite each other.

## Key files
- `app/lib/provider/hub/hub_call_provider.dart` — all call logic, guards, notification calls
- `app/lib/pages/hub/hub_voice_call_page.dart` — removed double-pop from End Call button
- `app/android/app/src/main/kotlin/org/localsend/localsend_app/MainActivity.kt` — notification methods, onNewIntent handler
- `app/android/app/src/main/AndroidManifest.xml` — USE_FULL_SCREEN_INTENT, showWhenLocked, turnScreenOn
