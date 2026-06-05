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
- `desktopPaddingFix` — getter in theme.dart (import theme to use it)

## Completed UI redesign files (all logic unchanged) — FULL COVERAGE
### Widgets
- `app/lib/widget/list_tile/custom_list_tile.dart` — glassmorphic card tile with cyan icon circle
- `app/lib/widget/list_tile/device_list_tile.dart` — device tile with favorite heart button
- `app/lib/widget/device_bage.dart` — pill badge with cyan glow border
- `app/lib/widget/custom_progress_bar.dart` — cyan gradient linear progress bar
- `app/lib/widget/custom_icon_button.dart` — frosted circle button
- `app/lib/widget/big_button.dart` — filled/unfilled gradient card button
- `app/lib/widget/local_send_logo.dart` — radial glow circle + ShaderMask gradient text
- `app/lib/widget/custom_basic_appbar.dart` — frosted back button, macOS MoveWindow preserved
- `app/lib/widget/debug_entry.dart` — styled debug entry row

### Pages & Tabs
- `app/lib/pages/home_page.dart` — ShaderMask gradient title on desktop rail, cyan drop indicator circle
- `app/lib/pages/tabs/send_tab.dart` — glassmorphic file selection card
- `app/lib/pages/tabs/receive_tab.dart` — gradient alias title, online badge, frosted info box
- `app/lib/pages/tabs/settings_tab.dart` — glassmorphic section cards with cyan accent bar
- `app/lib/pages/progress_page.dart` — glassmorphic progress card at bottom with cyan glow
- `app/lib/pages/receive_page.dart` — gradient background, glassmorphic message box
- `app/lib/pages/send_page.dart` — gradient background
- `app/lib/pages/web_send_page.dart` — glassmorphic URL card + session cards
- `app/lib/pages/receive_history_page.dart` — glassmorphic history item cards
- `app/lib/pages/selected_files_page.dart` — glassmorphic file cards
- `app/lib/pages/receive_options_page.dart` — glassmorphic file option cards
- `app/lib/pages/apk_picker_page.dart` — glassmorphic app list with selection highlight
- `app/lib/pages/troubleshoot_page.dart` — glassmorphic troubleshoot cards, monospace commands
- `app/lib/pages/about/about_page.dart` — glassmorphic links card
- `app/lib/pages/language_page.dart` — glassmorphic locale tiles with active state
- `app/lib/pages/changelog_page.dart` — brand palette MarkdownStyleSheet
- `app/lib/pages/donation/donation_page.dart` — purple gradient background
- `app/lib/pages/settings/network_interfaces_page.dart` — glassmorphic interface cards
- `app/lib/pages/debug/debug_page.dart` — glassmorphic button group container
- `app/lib/pages/debug/discovery_debug_page.dart` — teal log timestamps
- `app/lib/pages/debug/http_logs_page.dart` — teal log timestamps
- `app/lib/pages/debug/security_debug_page.dart` — auto-styled (no changes needed)

### Dialogs — all auto-styled via theme.dart (no individual rewrites needed)
- `dialogTheme` → AlertDialog: kCardSurface bg, 24px border-radius, no elevation
- `filledButtonTheme` → kAccentCyan bg, kBgDark fg
- `bottomSheetTheme` → kCardSurface bg, rounded top 24px
- `switchTheme`, `checkboxTheme`, `floatingActionButtonTheme`, `popupMenuTheme` all set

## Core glassmorphic card pattern
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    gradient: isDark
        ? LinearGradient(colors: [Color(0xFF1A2235), Color(0xFF111827)], ...)
        : LinearGradient(colors: [Colors.white, Color(0xFFF0F4FF)], ...),
    border: Border.all(color: isDark ? kGlassBorder : Color(0x1A000000), width: 1),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: Offset(0, 6))],
  ),
  child: ClipRRect(borderRadius: ..., child: Material(type: transparency, child: InkWell(...))),
)
```

## Icon circle pattern
```dart
Container(
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)]),
    border: Border.all(color: kAccentCyan.withValues(alpha: 0.3), width: 1.5),
    boxShadow: [BoxShadow(color: kAccentCyan.withValues(alpha: 0.15), blurRadius: 12)],
  ),
)
```

## Rules (follow on every future edit)
- NEVER change callbacks, providers, navigation, state management, or widget constructors/params
- Only change: Container colors/gradients, BoxDecoration, borders, shadows, Text styles, Icon colors/sizes
- The original LocalSend clone at /tmp/localsend_original is ephemeral — may not persist between sessions
- HomeTab enum icon fields changed to *_rounded variants (pure visual, zero logic impact)
- SessionState abstract class lives in app/lib/model/state/server/receive_session_state.dart
- Warning/error: use colorScheme.warning (it's defined in theme.dart extension) — do NOT replace with Colors.orangeAccent
