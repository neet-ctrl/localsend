import 'dart:async';
import 'dart:ui';

import 'package:common/model/device.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/receive_options_page.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/device_bage.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceivePageVm {
  final SessionStatus? status;
  final Device sender;
  final bool showSenderInfo;
  final List<FileDto> files;
  final String? message;
  final bool isLink;
  final void Function() onAccept;
  final void Function() onDecline;
  final void Function() onClose;

  ReceivePageVm({
    required this.status,
    required this.sender,
    required this.showSenderInfo,
    required this.files,
    required this.message,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  }) : isLink = message != null && !message.trim().contains(RegExp(r'\s')) && (Uri.tryParse(message.trim())?.isAbsolute ?? false);
}

class ReceivePage extends StatefulWidget {
  final ViewProvider<ReceivePageVm> vm;

  const ReceivePage(this.vm);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> with Refena {
  bool _showFullIp = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(
      widget.vm,
      listener: (prev, next) {
        if (prev.status != next.status) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(next.status);
        }
      },
    );

    if (vm.status == null && vm.message == null) {
      return const Scaffold(body: SizedBox());
    }

    final senderFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(vm.sender)));

    return ViewModelBuilder(
      provider: (ref) => widget.vm,
      onFirstFrame: (context, vm) {
        ref.notifier(selectedReceivingFilesProvider).setFiles(vm.files);
      },
      dispose: (ref) {
        ref.dispose(widget.vm);
        unawaited(TaskbarHelper.clearProgressBar());
      },
      builder: (context, vm) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) vm.onDecline();
          },
          canPop: true,
          child: Scaffold(
            backgroundColor: kBgDark,
            body: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [Color(0xFF0D1A2E), kBgDark],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
                    child: Builder(
                      builder: (context) {
                        final height = MediaQuery.of(context).size.height;
                        final smallUi = vm.message != null && height < 600;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: smallUi ? 20 : 30),
                          child: Column(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Device icon with glow
                                    if (vm.showSenderInfo && !smallUi)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _GlowingDeviceIcon(vm.sender.deviceType.icon),
                                      ),

                                    // Sender name
                                    Builder(
                                      builder: (context) {
                                        final alias = senderFavoriteEntry?.alias ?? vm.sender.alias;
                                        if (alias.isEmpty) {
                                          return Text('', style: TextStyle(fontSize: smallUi ? 32 : 48));
                                        }
                                        return FittedBox(
                                          child: ShaderMask(
                                            shaderCallback: (bounds) => const LinearGradient(
                                              colors: [Colors.white, Color(0xFFCCEEFF)],
                                            ).createShader(bounds),
                                            child: Text(
                                              alias,
                                              style: TextStyle(
                                                fontSize: smallUi ? 32 : 48,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // IP / model badges
                                    if (vm.showSenderInfo) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(() => _showFullIp = !_showFullIp),
                                            child: DeviceBadge(
                                              backgroundColor: kAccentCyan.withOpacity(0.12),
                                              foregroundColor: kAccentCyan,
                                              label: switch (vm.sender.ip) {
                                                String ip => _showFullIp ? ip : '#${ip.visualId}',
                                                null => 'WebRTC',
                                              },
                                            ),
                                          ),
                                          if (vm.sender.deviceModel != null) ...[
                                            const SizedBox(width: 10),
                                            DeviceBadge(
                                              backgroundColor: kAccentPurple.withOpacity(0.12),
                                              foregroundColor: kAccentPurple,
                                              label: vm.sender.deviceModel!,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],

                                    const SizedBox(height: 40),

                                    // Sub-title
                                    Text(
                                      vm.message != null
                                          ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage)
                                          : t.receivePage.subTitle(n: vm.files.length),
                                      style: (smallUi ? null : Theme.of(context).textTheme.titleLarge)?.copyWith(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    // Message card
                                    if (vm.message != null)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 20),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                                child: Container(
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    color: kGlassFill,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: kGlassBorder, width: 1),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(12),
                                                      child: SelectableText(
                                                        vm.message!,
                                                        style: const TextStyle(color: Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _NeonOutlineButton(
                                                label: t.general.copy,
                                                color: kAccentCyan,
                                                onPressed: () {
                                                  unawaited(Clipboard.setData(ClipboardData(text: vm.message!)));
                                                  if (checkPlatformIsDesktop()) {
                                                    context.showSnackBar(t.general.copiedToClipboard);
                                                  }
                                                  vm.onAccept();
                                                  context.pop();
                                                },
                                              ),
                                              if (vm.isLink) ...[
                                                const SizedBox(width: 16),
                                                _NeonFilledButton(
                                                  label: t.general.open,
                                                  onPressed: () {
                                                    // ignore: discarded_futures
                                                    launchUrl(Uri.parse(vm.message!), mode: LaunchMode.externalApplication);
                                                    vm.onAccept();
                                                    context.pop();
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              _Actions(vm),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowingDeviceIcon extends StatelessWidget {
  final IconData icon;
  const _GlowingDeviceIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAccentCyan.withOpacity(0.12),
        border: Border.all(color: kAccentCyan.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: kAccentCyan.withOpacity(0.25), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Icon(icon, size: 40, color: kAccentCyan),
    );
  }
}

class _NeonFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _NeonFilledButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
        boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.35), blurRadius: 14)],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _NeonOutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _NeonOutlineButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _Actions extends StatelessWidget {
  final ReceivePageVm vm;
  const _Actions(this.vm);

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedReceivingFilesProvider);

    if (vm.message != null) {
      return Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.6)),
          onPressed: () {
            vm.onAccept();
            context.pop();
          },
          icon: const Icon(Icons.close),
          label: Text(t.general.close),
        ),
      );
    }

    if (vm.status == SessionStatus.canceledBySender) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              t.receivePage.canceled,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: _NeonFilledButton(
              label: t.general.close,
              onPressed: () {
                vm.onClose();
                context.pop();
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.55),
            ),
            onPressed: () async {
              await context.push(() => ReceiveOptionsPage(vm));
            },
            icon: const Icon(Icons.settings, size: 18),
            label: Text(t.receiveOptionsPage.title),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NeonOutlineButton(
              label: t.general.decline,
              color: Colors.redAccent,
              onPressed: () {
                vm.onDecline();
                context.pop();
              },
            ),
            const SizedBox(width: 20),
            _NeonFilledButton(
              label: t.general.accept,
              onPressed: selectedFiles.isEmpty ? () {} : () => vm.onAccept(),
            ),
          ],
        ),
      ],
    );
  }
}
