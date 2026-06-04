import 'dart:async';
import 'dart:ui';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/animations/initial_slide_transition.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const SendPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with Refena {
  Device? _myDevice;
  Device? _targetDevice;

  @override
  void dispose() {
    super.dispose();
    unawaited(TaskbarHelper.clearProgressBar());
  }

  void _cancel() {
    final myDevice = ref.read(deviceFullInfoProvider);
    final sendState = ref.read(sendProvider)[widget.sessionId];
    if (sendState == null) return;

    setState(() {
      _myDevice = myDevice;
      _targetDevice = sendState.target;
    });
    ref.notifier(sendProvider).cancelSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final sendState = ref.watch(
      sendProvider.select((state) => state[widget.sessionId]),
      listener: (prev, next) {
        final prevStatus = prev[widget.sessionId]?.status;
        final nextStatus = next[widget.sessionId]?.status;
        if (prevStatus != nextStatus) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(nextStatus);
        }
      },
    );

    if (sendState == null && _myDevice == null && _targetDevice == null) {
      return const Scaffold(body: SizedBox());
    }

    final myDevice = ref.watch(deviceFullInfoProvider);
    final targetDevice = sendState?.target ?? _targetDevice!;
    final targetFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(targetDevice)));
    final waiting = sendState?.status == SessionStatus.waiting;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.closeSessionOnClose) _cancel();
      },
      canPop: true,
      child: Scaffold(
        backgroundColor: kBgDark,
        appBar: widget.showAppBar ? basicLocalSendAppbar('') : null,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.4,
              colors: [Color(0xFF0D1A2E), kBgDark],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
                  child: Column(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InitialSlideTransition(
                              origin: const Offset(0, -1),
                              duration: const Duration(milliseconds: 400),
                              child: DeviceListTile(device: myDevice),
                            ),
                            const SizedBox(height: 24),
                            InitialFadeTransition(
                              duration: const Duration(milliseconds: 300),
                              delay: const Duration(milliseconds: 400),
                              child: _AnimatedArrow(),
                            ),
                            const SizedBox(height: 24),
                            Hero(
                              tag: 'device-${targetDevice.ip}',
                              child: DeviceListTile(
                                device: targetDevice,
                                nameOverride: targetFavoriteEntry?.alias,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sendState != null)
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 400),
                          child: Column(
                            children: [
                              switch (sendState.status) {
                                SessionStatus.waiting => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    t.sendPage.waiting,
                                    style: TextStyle(color: Colors.white.withOpacity(0.65)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SessionStatus.declined => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    t.sendPage.rejected,
                                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SessionStatus.tooManyAttempts => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    t.sendPage.tooManyAttempts,
                                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SessionStatus.recipientBusy => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    t.sendPage.busy,
                                    style: const TextStyle(color: Colors.orangeAccent),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SessionStatus.finishedWithErrors => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t.general.error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                      if (sendState.errorMessage != null)
                                        TextButton(
                                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                                          onPressed: () async => showDialog(
                                            context: context,
                                            builder: (_) => ErrorDialog(error: sendState.errorMessage!),
                                          ),
                                          child: const Icon(Icons.info),
                                        ),
                                    ],
                                  ),
                                ),
                                _ => const SizedBox(),
                              },
                              Center(
                                child: _NeonActionButton(
                                  icon: waiting ? Icons.close : Icons.check_circle,
                                  label: waiting ? t.general.cancel : t.general.close,
                                  isDestructive: waiting,
                                  onPressed: () {
                                    _cancel();
                                    context.pop();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedArrow extends StatefulWidget {
  @override
  State<_AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<_AnimatedArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 8).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccentCyan.withOpacity(0.12),
            border: Border.all(color: kAccentCyan.withOpacity(0.3), width: 1),
            boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.2), blurRadius: 12)],
          ),
          child: const Icon(Icons.arrow_downward, color: kAccentCyan, size: 22),
        ),
      ),
    );
  }
}

class _NeonActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _NeonActionButton({
    required this.icon,
    required this.label,
    required this.isDestructive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : kAccentCyan;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isDestructive
            ? null
            : const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
        color: isDestructive ? Colors.redAccent.withOpacity(0.15) : null,
        border: isDestructive ? Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1) : null,
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}
