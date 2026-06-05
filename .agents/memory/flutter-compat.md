---
name: Flutter 3.35 / refena_flutter-3.1.0 API Compat
description: Parameters that do NOT exist in the CI build environment (Flutter stable-3.35.6, refena_flutter 3.1.0) — using them causes compile errors.
---

## Removed / non-existent parameters

### ToggleButtonsThemeData (Flutter stable-3.35.6)
- `selectedFillColor` does NOT exist — remove it; use only `selectedColor`, `color`, `borderColor`, `selectedBorderColor`, `borderRadius`.

### ViewModelBuilder (refena_flutter-3.1.0)
- `listener:` parameter does NOT exist.
- **Workaround:** Track previous value in `State` class (e.g. `SessionStatus? _prevStatus`) and compare inside `builder:` callback. Call side-effects (e.g. `TaskbarHelper.visualizeStatus`) from there.

## Known-good send_provider.dart pattern
- After `prepareUpload` response, store remote session ID as `final remoteSessionId = response.response!.sessionId` (NOT `final sessionId`) to avoid shadowing the local session UUID used as the state map key.

**Why:** Variable shadowing caused `updateSession` to look up the wrong key → `remoteSessionId` was never stored → upload requests omitted `sessionId` query param → server returned 400.
