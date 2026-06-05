import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/native/platform_check.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const CustomIconButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        splashColor: kAccentCyan.withValues(alpha: 0.12),
        highlightColor: kAccentCyan.withValues(alpha: 0.06),
        child: Container(
          padding: checkPlatformIsDesktop()
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
              : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? kGlassFill : const Color(0x0A000000),
            border: Border.all(
              color: isDark ? kGlassBorder : const Color(0x12000000),
              width: 1,
            ),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: isDark ? const Color(0xFFB0BDD0) : const Color(0xFF4A5568),
              size: 20,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
