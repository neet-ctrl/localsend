import 'dart:ui';

import 'package:common/util/sleep.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/qr_dialog.dart';
import 'package:localsend_app/widget/dialogs/zoom_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _ServerState { initializing, running, error, stopping }

class WebSendPage extends StatefulWidget {
  final List<CrossFile> files;

  const WebSendPage(this.files);

  @override
  State<WebSendPage> createState() => _WebSendPageState();
}

class _WebSendPageState extends State<WebSendPage> with Refena {
  _ServerState _stateEnum = _ServerState.initializing;
  bool _encrypted = false;
  String? _initializedError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init(encrypted: false);
    });
  }

  void _init({required bool encrypted}) async {
    final settings = ref.read(settingsProvider);
    final (beforeAutoAccept, beforePin) =
        ref.read(serverProvider.select((state) => (state?.webSendState?.autoAccept, state?.webSendState?.pin)));
    setState(() {
      _stateEnum = _ServerState.initializing;
      _encrypted = encrypted;
      _initializedError = null;
    });
    await sleepAsync(500);
    try {
      await ref.notifier(serverProvider).restartServer(
        alias: settings.alias,
        port: settings.port,
        https: _encrypted,
      );
      await ref.notifier(serverProvider).initializeWebSend(widget.files);
      if (beforeAutoAccept != null) {
        ref.notifier(serverProvider).setWebSendAutoAccept(beforeAutoAccept);
      }
      ref.notifier(serverProvider).setWebSendPin(beforePin);
      setState(() => _stateEnum = _ServerState.running);
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _stateEnum = _ServerState.error;
          _initializedError = e.toString();
        });
      }
    }
  }

  Future<void> _revertServerState() async {
    await ref.notifier(serverProvider).restartServerFromSettings();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) async {
        if (_stateEnum != _ServerState.running) return;
        setState(() => _stateEnum = _ServerState.stopping);
        await sleepAsync(250);
        await _revertServerState();
        await sleepAsync(250);
        if (context.mounted) context.pop();
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: kBgDark,
        appBar: basicLocalSendAppbar(t.webSharePage.title),
        body: Builder(
          builder: (context) {
            if (_stateEnum != _ServerState.running) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping) ...[
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(kAccentCyan),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _stateEnum == _ServerState.initializing ? t.webSharePage.loading : t.webSharePage.stopping,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    ] else if (_initializedError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.14),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
                        ),
                        child: const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 20),
                      Text(t.webSharePage.error,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: SelectableText(
                          _initializedError!,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }

            final serverState = context.watch(serverProvider)!;
            final webSendState = serverState.webSendState!;
            final networkState = context.watch(localIpProvider);

            return ResponsiveListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              children: [
                // URLs card
                _SectionLabel(t.webSharePage.openLink(n: networkState.localIps.length)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kGlassFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kGlassBorder, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...networkState.localIps.map((ip) {
                              final url = '${_encrypted ? 'https' : 'http'}://$ip:${serverState.port}';
                              final urlWithPin = switch (webSendState.pin) {
                                String() => '$url/?pin=${Uri.encodeQueryComponent(webSendState.pin!)}',
                                null => url,
                              };
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        url,
                                        style: TextStyle(
                                          color: kAccentCyan,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'RobotoMono',
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    _UrlAction(
                                      icon: Icons.content_copy,
                                      tooltip: t.general.copy,
                                      onTap: () async {
                                        await Clipboard.setData(ClipboardData(text: url));
                                        if (context.mounted && checkPlatformIsDesktop()) {
                                          context.showSnackBar(t.general.copiedToClipboard);
                                        }
                                      },
                                    ),
                                    _UrlAction(
                                      icon: Icons.qr_code,
                                      tooltip: 'QR Code',
                                      onTap: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => QrDialog(
                                            data: urlWithPin,
                                            label: url,
                                            listenIncomingWebSendRequests: true,
                                            pin: webSendState.pin,
                                          ),
                                        );
                                      },
                                    ),
                                    _UrlAction(
                                      icon: Icons.tv,
                                      tooltip: 'Zoom',
                                      onTap: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => ZoomDialog(
                                            label: url,
                                            pin: webSendState.pin,
                                            listenIncomingWebSendRequests: true,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Requests
                _SectionLabel(t.webSharePage.requests),
                const SizedBox(height: 8),
                if (webSendState.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 4),
                    child: Text(t.webSharePage.noRequests, style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  ),
                ...webSendState.sessions.entries.map((entry) {
                  final session = entry.value;
                  final pending = session.responseHandler != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: pending ? kAccentCyan.withOpacity(0.08) : kGlassFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: pending ? kAccentCyan.withOpacity(0.3) : kGlassBorder,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.deviceInfo,
                                        style: TextStyle(
                                          color: pending ? kAccentCyan : Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        session.ip,
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (pending) ...[
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                    onPressed: () => ref.notifier(serverProvider).declineWebSendRequest(session.sessionId),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: kAccentCyan, size: 20),
                                    onPressed: () => ref.notifier(serverProvider).acceptWebSendRequest(session.sessionId),
                                  ),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      t.general.accepted,
                                      style: TextStyle(color: kAccentCyan.withOpacity(0.7), fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // Options card
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kGlassFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kGlassBorder, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: t.webSharePage.encryption,
                              value: _encrypted,
                              onChanged: (value) => _init(encrypted: value),
                            ),
                            if (_encrypted)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  t.webSharePage.encryptionHint,
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                ),
                              ),
                            _ToggleRow(
                              label: t.webSharePage.autoAccept,
                              value: webSendState.autoAccept,
                              onChanged: (value) => ref.notifier(serverProvider).setWebSendAutoAccept(value),
                            ),
                            _ToggleRow(
                              label: t.webSharePage.requirePin,
                              value: webSendState.pin != null,
                              onChanged: (value) async {
                                final currentPIN = webSendState.pin;
                                if (currentPIN != null) {
                                  ref.notifier(serverProvider).setWebSendPin(null);
                                } else {
                                  final String? newPin = await showDialog<String>(
                                    context: context,
                                    builder: (_) => const PinDialog(obscureText: false, generateRandom: true),
                                  );
                                  if (newPin != null && newPin.isNotEmpty) {
                                    ref.notifier(serverProvider).setWebSendPin(newPin);
                                  }
                                }
                              },
                            ),
                            if (webSendState.pin != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  t.webSharePage.pinHint(pin: webSendState.pin!),
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [kAccentCyan, kAccentPurple],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: kAccentCyan.withOpacity(0.4),
            activeColor: kAccentCyan,
            inactiveThumbColor: Colors.white.withOpacity(0.4),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ],
      ),
    );
  }
}

class _UrlAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _UrlAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: kAccentCyan.withOpacity(0.7)),
        ),
      ),
    );
  }
}
