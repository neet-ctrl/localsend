import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';

class DeviceBadge extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;

  const DeviceBadge({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor == Colors.transparent ? Colors.transparent : kAccentCyan.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: foregroundColor == Colors.transparent ? Colors.transparent : kAccentCyan.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor == Colors.transparent ? Colors.transparent : kAccentCyan,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
