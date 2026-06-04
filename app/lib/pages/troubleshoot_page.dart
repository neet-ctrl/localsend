import 'dart:io';
import 'dart:ui';

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
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.troubleshootPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
        children: [
          Text(
            t.troubleshootPage.subTitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
          ),
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
                TargetPlatform.windows: _CommandFixAction(adminPrivileges: false, commands: ['wf']),
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
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: kGlassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Symptom with neon left border accent
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10, top: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [kAccentCyan, kAccentPurple],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.symptomText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.troubleshootPage.solution,
                    style: TextStyle(color: kAccentCyan.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.solutionText,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  ),
                  if (widget.primaryButton != null) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      runSpacing: 10,
                      spacing: 10,
                      children: [
                        widget.primaryButton!,
                        if (widget.secondaryButton != null) widget.secondaryButton!,
                        if (widget.primaryButton!.onTap?.commands != null)
                          CustomIconButton(
                            onPressed: () => setState(() => _showCommands = !_showCommands),
                            child: Icon(
                              Icons.terminal,
                              color: _showCommands ? kAccentCyan : Colors.white.withOpacity(0.45),
                            ),
                          ),
                      ],
                    ),
                    AnimatedCrossFade(
                      crossFadeState: _showCommands ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                      firstChild: Container(),
                      secondChild: SelectionArea(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kBgDark.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kAccentCyan.withOpacity(0.2), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...?widget.primaryButton?.onTap?.commands?.map((cmd) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    cmd,
                                    style: const TextStyle(
                                      fontFamily: 'RobotoMono',
                                      color: kAccentCyan,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    return Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
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

  _CommandFixAction({required this.adminPrivileges, required this.commands});

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
  void runFix() async => await action();
}
