import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';

class CustomProgressBar extends StatelessWidget {
  final double? progress;
  final double borderRadius;
  final Color? color;

  const CustomProgressBar({required this.progress, this.borderRadius = 10, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          // Track
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: kGlassFill,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: progress?.clamp(0.0, 1.0),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  colors: color != null
                      ? [color!, color!.withOpacity(0.7)]
                      : const [kAccentCyan, kAccentPurple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (color ?? kAccentCyan).withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
