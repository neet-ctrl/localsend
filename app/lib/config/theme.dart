import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/dynamic_colors.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:yaru/yaru.dart' as yaru;

final _borderRadius = BorderRadius.circular(16);

double get desktopPaddingFix => checkPlatformIsDesktop() ? 8 : 0;

// ── Brand palette ──────────────────────────────────────────────────────────
const kBgDark = Color(0xFF070B14);
const kBgDark2 = Color(0xFF0D1220);
const kAccentCyan = Color(0xFF00E5FF);
const kAccentPurple = Color(0xFF7C4DFF);
const kGlassBorder = Color(0x26FFFFFF);
const kGlassFill = Color(0x0DFFFFFF);
const kSurface = Color(0xFF111827);
const kCardSurface = Color(0xFF1A2235);

ThemeData getTheme(ColorMode colorMode, Brightness brightness, DynamicColors? dynamicColors) {
  if (colorMode == ColorMode.yaru) {
    return _getYaruTheme(brightness);
  }

  return _buildSpaceTheme(brightness);
}

ThemeData _buildSpaceTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: kAccentCyan,
    onPrimary: kBgDark,
    secondary: kAccentPurple,
    onSecondary: Colors.white,
    error: const Color(0xFFFF4D6D),
    onError: Colors.white,
    surface: isDark ? kSurface : const Color(0xFFF0F4FF),
    onSurface: isDark ? Colors.white : const Color(0xFF0D1220),
    surfaceContainerHighest: isDark ? kCardSurface : const Color(0xFFE8EFFF),
    onSurfaceVariant: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
    outline: isDark ? const Color(0xFF2A3A5C) : const Color(0xFFCBD5E1),
    secondaryContainer: isDark ? const Color(0xFF1E2D47) : const Color(0xFFDEEAFF),
    onSecondaryContainer: isDark ? kAccentCyan : const Color(0xFF1A2235),
    primaryContainer: isDark ? const Color(0xFF003D52) : const Color(0xFFCCF5FF),
    onPrimaryContainer: isDark ? kAccentCyan : const Color(0xFF003D52),
    tertiary: const Color(0xFF00BFA5),
    onTertiary: Colors.white,
    tertiaryContainer: isDark ? const Color(0xFF003D35) : const Color(0xFFCCF2EC),
    onTertiaryContainer: isDark ? const Color(0xFF00BFA5) : const Color(0xFF003D35),
    inverseSurface: isDark ? Colors.white : kBgDark,
    onInverseSurface: isDark ? kBgDark : Colors.white,
    inversePrimary: const Color(0xFF006B82),
    shadow: Colors.black54,
    scrim: Colors.black87,
    surfaceTint: kAccentCyan.withValues(alpha: 0.08),
  );

  final String? fontFamily;
  if (checkPlatform([TargetPlatform.windows])) {
    fontFamily = switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Yu Gothic UI',
      AppLocale.ko => 'Malgun Gothic',
      AppLocale.zhCn => 'Microsoft YaHei UI',
      AppLocale.zhHk || AppLocale.zhTw => 'Microsoft JhengHei UI',
      _ => 'Segoe UI Variable Display',
    };
  } else if (checkPlatform([TargetPlatform.linux])) {
    fontFamily = switch (LocaleSettings.currentLocale) {
      AppLocale.ja => 'Noto Sans CJK JP',
      AppLocale.ko => 'Noto Sans CJK KR',
      AppLocale.zhCn => 'Noto Sans CJK SC',
      AppLocale.zhHk || AppLocale.zhTw => 'Noto Sans CJK TC',
      _ => 'Noto Sans',
    };
  } else {
    fontFamily = null;
  }

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: isDark ? kBgDark : const Color(0xFFF5F8FF),
    fontFamily: fontFamily,
    cardTheme: CardThemeData(
      color: isDark ? kCardSurface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000), width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF0D1627) : Colors.white,
      indicatorColor: kAccentCyan.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kAccentCyan, size: 24);
        }
        return IconThemeData(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3);
        }
        return TextStyle(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), fontSize: 12);
      }),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark ? kBgDark2 : const Color(0xFFF0F4FF),
      indicatorColor: kAccentCyan.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: kAccentCyan),
      unselectedIconTheme: IconThemeData(color: isDark ? const Color(0xFF4A5568) : const Color(0xFF9AA5B4)),
      selectedLabelTextStyle: const TextStyle(color: kAccentCyan, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: isDark ? const Color(0xFF4A5568) : const Color(0xFF9AA5B4)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? kGlassFill : const Color(0xFFF0F4FF),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
        borderRadius: _borderRadius,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: kAccentCyan, width: 1.5),
        borderRadius: _borderRadius,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
        borderRadius: _borderRadius,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentCyan,
        foregroundColor: kBgDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12 + desktopPaddingFix),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccentCyan,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8 + desktopPaddingFix),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? kGlassFill : const Color(0xFFF0F4FF),
      selectedColor: kAccentCyan.withValues(alpha: 0.2),
      side: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A2235), fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF1E2D47) : const Color(0xFFE2E8F0),
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? kBgDark : Colors.white,
      foregroundColor: isDark ? Colors.white : const Color(0xFF0D1220),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0D1220),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? kCardSurface : Colors.white,
      contentTextStyle: TextStyle(color: isDark ? Colors.white : const Color(0xFF0D1220)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? kCardSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
      ),
      titleTextStyle: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0D1220),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      contentTextStyle: TextStyle(
        color: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
        fontSize: 14,
      ),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccentCyan,
        foregroundColor: kBgDark,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12 + desktopPaddingFix),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? kCardSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
      textColor: isDark ? Colors.white : const Color(0xFF0D1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kBgDark;
        return isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kAccentCyan;
        return isDark ? const Color(0xFF2A3A5C) : const Color(0xFFCBD5E1);
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kAccentCyan;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(kBgDark),
      side: BorderSide(color: isDark ? kGlassBorder : const Color(0x40000000), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kAccentCyan,
      foregroundColor: kBgDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      selectedColor: kAccentCyan,
      color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
      borderColor: isDark ? kGlassBorder : const Color(0x1A000000),
      selectedBorderColor: kAccentCyan.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? kCardSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
      ),
      textStyle: TextStyle(color: isDark ? Colors.white : const Color(0xFF0D1220), fontSize: 14),
    ),
  );
}

Future<void> updateSystemOverlayStyle(BuildContext context) async {
  final brightness = Theme.of(context).brightness;
  await updateSystemOverlayStyleWithBrightness(brightness);
}

Future<void> updateSystemOverlayStyleWithBrightness(Brightness brightness) async {
  if (checkPlatform([TargetPlatform.android])) {
    final darkMode = brightness == Brightness.dark;
    final androidSdkInt = RefenaScope.defaultRef.read(deviceInfoProvider).androidSdkInt ?? 0;
    final bool edgeToEdge = androidSdkInt >= 29;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: edgeToEdge ? Colors.transparent : (darkMode ? kBgDark : Colors.white),
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
      ),
    );
  } else {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: brightness,
        statusBarColor: Colors.transparent,
      ),
    );
  }
}

extension ThemeDataExt on ThemeData {
  Color get cardColorWithElevation {
    return ElevationOverlay.applySurfaceTint(cardColor, colorScheme.surfaceTint, 1);
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get warning => const Color(0xFFFFB300);
  Color? get secondaryContainerIfDark => brightness == Brightness.dark ? secondaryContainer : null;
  Color? get onSecondaryContainerIfDark => brightness == Brightness.dark ? onSecondaryContainer : null;
}

extension InputDecorationThemeExt on InputDecorationThemeData {
  BorderRadius get borderRadius => _borderRadius;
}

ThemeData _getYaruTheme(Brightness brightness) {
  final baseTheme = brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
  final colorScheme = baseTheme.colorScheme;

  final border = OutlineInputBorder(
    borderSide: BorderSide(color: colorScheme.secondaryContainer),
    borderRadius: _borderRadius,
  );

  InputDecorationThemeData;

  return baseTheme.copyWith(
    navigationBarTheme: colorScheme.brightness == Brightness.dark
        ? NavigationBarThemeData(
            iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
          )
        : null,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.secondaryContainer,
      border: border,
      focusedBorder: border,
      enabledBorder: border,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: colorScheme.brightness == Brightness.dark ? Colors.white : null,
        padding: checkPlatformIsDesktop() ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: checkPlatformIsDesktop() ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
  );
}
