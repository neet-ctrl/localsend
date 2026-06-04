import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/widget/copyable_text.dart';

class DebugEntry extends StatelessWidget {
  static const headerStyle = TextStyle(
    fontWeight: FontWeight.w600,
    color: kAccentCyan,
    fontSize: 12,
  );

  final String name;
  final String? value;

  const DebugEntry({
    required this.name,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: headerStyle),
          const SizedBox(height: 2),
          CopyableText(name: name, value: value),
          Divider(color: kGlassBorder, thickness: 1, height: 1),
        ],
      ),
    );
  }
}
