import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/cmd_helper.dart';
import 'package:localsend_app/util/native/macos_channel.dart' as macos_channel;
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/dialogs/not_available_on_platform_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class TroubleshootPage extends StatelessWidget {
  const TroubleshootPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.ref.watch(settingsProvider);
    return Scaffold(
      appBar: basicLocalSendAppbar(t.troubleshootPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
        children: [
          Text(t.troubleshootPage.subTitle, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          _TroubleshootItem(
            symptomText: t.troubleshootPage.firewall.symptom,
            solutionText: t.troubleshootPage.firewall.solution(port: settings.port),
            primaryButton: _FixButton(
              label: t.troubleshootPage.fixButton,
              onTapMap: {
                TargetPlatform.windows: _CommandFixAction(
                  adminPrivileges: true,
                  commands: [
                    'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=TCP localport=${settings.port}',
                    'netsh advfirewall firewall add rule name="LocalSend" dir=in action=allow protocol=UDP localport=${settings.port}',
                  ],
                ),
              },
            ),
            secondaryButton: _FixButton(
              label: t.troubleshootPage.firewall.openFirewall,
              onTapMap: {
                TargetPlatform.windows: _CommandFixAction(
                  adminPrivileges: false,
                  commands: ['wf'],
                ),
                TargetPlatform.macOS: _NativeFixAction(() => macos_channel.openFirewallSettings()),
              },
            ),
          ),
          _TroubleshootItem(
            symptomText: t.troubleshootPage.noDiscovery.symptom,
            solutionText: t.troubleshootPage.noDiscovery.solution,
          ),
          _TroubleshootItem(
            symptomText: t.troubleshootPage.noConnection.symptom,
            solutionText: t.troubleshootPage.noConnection.solution,
          ),
        ],
      ),
    );
  }
}

class _TroubleshootItem extends StatefulWidget {
  final String symptomText;
  final String solutionText;
  final _FixButton? primaryButton;
  final _FixButton? secondaryButton;

  const _TroubleshootItem({
    required this.symptomText,
    required this.solutionText,
    this.primaryButton,
    this.secondaryButton,
  });

  @override
  State<_TroubleshootItem> createState() => _TroubleshootItemState();
}

class _TroubleshootItemState extends State<_TroubleshootItem> {
  bool _showCommands = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A2235), const Color(0xFF111827)]
                : [Colors.white, const Color(0xFFF0F4FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: kAccentCyan.withValues(alpha: 0.04),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.symptomText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(t.troubleshootPage.solution),
              Text(widget.solutionText),
              if (widget.primaryButton != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  runSpacing: 10,
                  children: [
                    widget.primaryButton!,
                    if (widget.secondaryButton != null) ...[
                      const SizedBox(width: 10),
                      widget.secondaryButton!,
                    ],
                    if (widget.primaryButton!.onTap?.commands != null) ...[
                      const SizedBox(width: 10),
                      CustomIconButton(
                        onPressed: () {
                          setState(() => _showCommands = !_showCommands);
                        },
                        child: const Icon(Icons.info),
                      ),
                    ],
                  ],
                ),
                AnimatedCrossFade(
                  crossFadeState: _showCommands ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  firstChild: Container(),
                  secondChild: SelectionArea(
                    child: Column(
                      children: [
                        ...?widget.primaryButton?.onTap?.commands?.map((cmd) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? kBgDark : const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
                              ),
                              child: Text(
                                cmd,
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  color: isDark ? kAccentCyan : const Color(0xFF0D1220),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final String label;
  final Map<TargetPlatform, _FixAction> onTapMap;
  final _FixAction? onTap;

  _FixButton({
    required this.label,
    required this.onTapMap,
  }) : onTap = onTapMap[defaultTargetPlatform];

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      onPressed: () async {
        if (onTap != null) {
          onTap!.runFix();
        } else {
          await showDialog(
            context: context,
            builder: (_) => NotAvailableOnPlatformDialog(platforms: onTapMap.keys.toList()),
          );
        }
      },
      child: Text(label),
    );
  }
}

abstract class _FixAction {
  void runFix();

  List<String>? get commands;
}

class _CommandFixAction extends _FixAction {
  final bool adminPrivileges;

  @override
  final List<String> commands;

  _CommandFixAction({
    required this.adminPrivileges,
    required this.commands,
  });

  @override
  void runFix() async {
    if (adminPrivileges) {
      if (checkPlatform([TargetPlatform.windows])) {
        await runWindowsCommandAsAdmin(commands);
      } else {
        throw 'Admin privileges are only implemented on Windows.';
      }
    } else {
      for (final c in commands) {
        await Process.run(c, [], runInShell: true);
      }
    }
  }
}

class _NativeFixAction extends _FixAction {
  final Future<void> Function() action;

  _NativeFixAction(this.action);

  @override
  List<String>? get commands => null;

  @override
  void runFix() async {
    await action();
  }
}
