import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/widget/responsive_builder.dart';

class BigButton extends StatelessWidget {
  static const double desktopWidth = 100.0;
  static const double mobileWidth = 90.0;

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const BigButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
    final buttonWidth = sizingInformation.isDesktop ? desktopWidth : mobileWidth;
    return SizedBox(
      width: buttonWidth,
      height: 80.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kAccentCyan, Color(0xFF00B8D9)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A2235), const Color(0xFF111827)]
                      : [Colors.white, const Color(0xFFF0F4FF)],
                ),
          border: Border.all(
            color: filled
                ? kAccentCyan.withValues(alpha: 0.6)
                : (isDark ? kGlassBorder : const Color(0x1A000000)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? kAccentCyan.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: filled ? 20 : 12,
              offset: const Offset(0, 6),
            ),
            if (filled)
              BoxShadow(
                color: kAccentCyan.withValues(alpha: 0.15),
                blurRadius: 40,
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Padding(
              padding: EdgeInsets.only(
                left: 2,
                right: 2,
                top: 10 + desktopPaddingFix,
                bottom: 8 + desktopPaddingFix,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: filled ? kBgDark : kAccentCyan,
                    size: 26,
                  ),
                  FittedBox(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: filled ? kBgDark : (isDark ? Colors.white : const Color(0xFF0D1220)),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
