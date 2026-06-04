import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

class SendModeHelpDialog extends StatelessWidget {
  const SendModeHelpDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.sendModeHelp.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SendModeItem(
                  mode: t.sendTab.sendModes.single,
                  explanation: t.dialogs.sendModeHelp.single,
                  icon: Icons.person,
                  color: kAccentCyan,
                ),
                const SizedBox(height: 12),
                _SendModeItem(
                  mode: t.sendTab.sendModes.multiple,
                  explanation: t.dialogs.sendModeHelp.multiple,
                  icon: Icons.people,
                  color: kAccentPurple,
                ),
                const SizedBox(height: 12),
                _SendModeItem(
                  mode: t.sendTab.sendModes.link,
                  explanation: t.dialogs.sendModeHelp.link,
                  icon: Icons.link,
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                    onPressed: () => context.pop(),
                    child: Text(t.general.close, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendModeItem extends StatelessWidget {
  final String mode;
  final String explanation;
  final IconData icon;
  final Color color;

  const _SendModeItem({
    required this.mode,
    required this.explanation,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 3),
              Text(explanation, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
