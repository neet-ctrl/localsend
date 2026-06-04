---
name: LocalSend Glassmorphic Design System
description: Complete UI redesign of LocalSend Flutter app — design tokens, patterns, and scope.
---

# Design System

## Color Constants (app/lib/config/theme.dart)
- `kBgDark` = `0xFF070B14` — primary background
- `kBgDark2` = `0xFF0D1220` — secondary background
- `kSurface` = `0xFF111827` — card/dialog surface
- `kCardSurface` = `0xFF1A2235` — elevated card
- `kGlassFill` = `0x0DFFFFFF` — frosted glass fill (13% white)
- `kGlassBorder` = `0x26FFFFFF` — frosted glass border (15% white)
- `kAccentCyan` = `0xFF00E5FF` — primary accent
- `kAccentPurple` = `0xFF7C4DFF` — secondary accent
- `desktopPaddingFix` — constant for desktop button padding

## Widget Patterns

### Dialog pattern
```dart
Dialog(backgroundColor: Colors.transparent,
  child: ClipRRect(borderRadius: 20,
    child: BackdropFilter(filter: blur(20,20),
      child: Container(color: kSurface, border: kGlassBorder))))
```

### Gradient action button
```dart
Container(gradient: LinearGradient([kAccentCyan, kAccentPurple]),
  boxShadow: [cyan 30% opacity blur 12],
  child: ElevatedButton(backgroundColor: transparent))
```

### Warning/error colors
- Use `Colors.orangeAccent` everywhere — never `colorScheme.warning`
- Use `Colors.redAccent` for destructive/delete actions

### Page scaffold
```dart
Scaffold(backgroundColor: kBgDark, appBar: basicLocalSendAppbar(title))
```

## Scope — all files rewritten
- All pages (home, send, receive, progress, history, settings, about, etc.)
- All tabs (send_tab, receive_tab, settings_tab)
- All dialogs (50+ dialog files)
- All debug pages (debug, security, http_logs, discovery)
- All core widgets (big_button, custom_basic_appbar, custom_progress_bar, etc.)

**Why:** User requested complete 3D glassmorphic redesign preserving all logic.
**How to apply:** Never use AlertDialog, colorScheme.warning, or colorScheme.onPrimary — these are all replaced.
