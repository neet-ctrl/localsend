import 'dart:ui';

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
    final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
    final buttonWidth = sizingInformation.isDesktop ? desktopWidth : mobileWidth;

    return SizedBox(
      width: buttonWidth,
      height: 72.0,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: filled
                    ? const LinearGradient(
                        colors: [kAccentCyan, kAccentPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: filled ? null : kGlassFill,
                border: Border.all(
                  color: filled ? Colors.transparent : kGlassBorder,
                  width: 1,
                ),
                boxShadow: filled
                    ? [BoxShadow(color: kAccentCyan.withOpacity(0.3), blurRadius: 16, spreadRadius: 1)]
                    : null,
              ),
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
                    color: filled ? Colors.white : kAccentCyan,
                    size: 24,
                  ),
                  FittedBox(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: filled ? Colors.white : Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
