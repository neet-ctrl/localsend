import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:legalize/legalize.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:uuid/uuid.dart';

enum _QuickAction {
  counter,
  random;

  String get label {
    switch (this) {
      case _QuickAction.counter:
        return t.dialogs.quickActions.counter;
      case _QuickAction.random:
        return t.dialogs.quickActions.random;
    }
  }
}

class QuickActionsDialog extends StatefulWidget {
  const QuickActionsDialog({super.key});

  @override
  State<QuickActionsDialog> createState() => _QuickActionsDialogState();
}

class _QuickActionsDialogState extends State<QuickActionsDialog> with Refena {
  _QuickAction _action = _QuickAction.counter;

  String _prefix = '';
  bool _padZero = false;
  bool _sortBeforehand = false;

  final _randomUuid = const Uuid().v4();

  bool _isValid = true;

  bool _validate(String input) {
    if (!isValidFilename(input, os: Platform.operatingSystem) && input.isNotEmpty) {
      setState(() => _isValid = false);
      return false;
    }
    if (!_isValid) setState(() => _isValid = true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.tips_and_updates, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.quickActions.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mode toggle
                Container(
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGlassBorder, width: 1),
                  ),
                  child: Row(
                    children: _QuickAction.values.map((mode) {
                      final isSelected = _action == mode;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _action = mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              gradient: isSelected
                                  ? const LinearGradient(colors: [kAccentCyan, kAccentPurple])
                                  : null,
                            ),
                            child: Text(
                              mode.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                if (_action == _QuickAction.counter) ...[
                  Text(
                    t.dialogs.quickActions.prefix,
                    style: const TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: kAccentCyan,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kGlassFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kGlassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kAccentCyan.withOpacity(0.5), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kGlassBorder),
                      ),
                      hintText: 'img_',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                    ),
                    onChanged: (s) {
                      _validate(s);
                      setState(() => _prefix = s);
                    },
                  ),
                  if (!_isValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(t.sanitization.invalid, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  LabeledCheckbox(
                    label: t.dialogs.quickActions.padZero,
                    value: _padZero,
                    onChanged: (b) => setState(() => _padZero = b == true),
                  ),
                  const SizedBox(height: 6),
                  LabeledCheckbox(
                    label: t.dialogs.quickActions.sortBeforeCount,
                    value: _sortBeforehand,
                    onChanged: (b) => setState(() => _sortBeforehand = b == true),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${t.general.example}: $_prefix${_padZero ? '04' : '4'}.jpg',
                    style: TextStyle(color: kAccentCyan.withOpacity(0.6), fontSize: 12, fontFamily: 'RobotoMono'),
                  ),
                ],

                if (_action == _QuickAction.random)
                  Text(
                    '${t.general.example}: $_randomUuid.jpg',
                    style: TextStyle(color: kAccentCyan.withOpacity(0.6), fontSize: 12, fontFamily: 'RobotoMono'),
                  ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.55)),
                      onPressed: () => context.pop(),
                      child: Text(t.general.cancel),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                        boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: () {
                          switch (_action) {
                            case _QuickAction.counter:
                              if (!_isValid) return;
                              ref.notifier(selectedReceivingFilesProvider).applyCounter(
                                prefix: _prefix,
                                padZero: _padZero,
                                sortFirst: _sortBeforehand,
                              );
                            case _QuickAction.random:
                              ref.notifier(selectedReceivingFilesProvider).applyRandom();
                          }
                          context.pop();
                        },
                        child: Text(t.general.confirm, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
