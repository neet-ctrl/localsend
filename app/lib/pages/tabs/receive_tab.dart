import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/receive_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/ip_helper.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _QuickSaveMode {
  off,
  favorites,
  on,
}

class ReceiveTab extends StatelessWidget {
  const ReceiveTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch(receiveTabVmProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        checkPlatform([TargetPlatform.macOS])
            ? SizedBox(height: 50, child: MoveWindow())
            : SizedBox(height: 0, width: 0), // makes the top part that's not occupied by another widget draggable
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: ColumnListView(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 200),
                          child: Consumer(
                            builder: (context, ref) {
                              final animations = ref.watch(animationProvider);
                              final activeTab = ref.watch(homePageControllerProvider.select((state) => state.currentTab));
                              return RotatingWidget(
                                duration: const Duration(seconds: 15),
                                spinning: vm.serverState != null && animations && activeTab == HomeTab.receive,
                                child: const LocalSendLogo(withText: false),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [kAccentCyan, Color(0xFF00B8D9)],
                            ).createShader(bounds),
                            child: Text(
                              vm.serverState?.alias ?? vm.aliasSettings,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 500),
                          child: Text(
                            vm.serverState == null ? t.general.offline : vm.localIps.map((ip) => '#${ip.visualId}').toSet().join(' '),
                            style: TextStyle(
                              fontSize: 18,
                              color: vm.serverState == null
                                  ? (isDark ? const Color(0xFF4A5568) : Colors.grey)
                                  : kAccentCyan,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (vm.serverState != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: kAccentCyan.withValues(alpha: 0.1),
                              border: Border.all(color: kAccentCyan.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kAccentCyan,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.general.online,
                                  style: const TextStyle(
                                    color: kAccentCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            t.general.quickSave,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<_QuickSaveMode>(
                            multiSelectionEnabled: false,
                            emptySelectionAllowed: false,
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) async {
                              if (selection.contains(_QuickSaveMode.off)) {
                                await vm.onSetQuickSave(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSaveFromFavorites(context, false);
                                }
                              } else if (selection.contains(_QuickSaveMode.favorites)) {
                                await vm.onSetQuickSave(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSaveFromFavorites(context, true);
                                }
                              } else if (selection.contains(_QuickSaveMode.on)) {
                                await vm.onSetQuickSaveFromFavorites(context, false);
                                if (context.mounted) {
                                  await vm.onSetQuickSave(context, true);
                                }
                              }
                            },
                            selected: {
                              if (!vm.quickSaveSettings && !vm.quickSaveFromFavoritesSettings) _QuickSaveMode.off,
                              if (vm.quickSaveFromFavoritesSettings) _QuickSaveMode.favorites,
                              if (vm.quickSaveSettings) _QuickSaveMode.on,
                            },
                            segments: [
                              ButtonSegment(
                                value: _QuickSaveMode.off,
                                label: Text(t.receiveTab.quickSave.off),
                              ),
                              ButtonSegment(
                                value: _QuickSaveMode.favorites,
                                label: Text(t.receiveTab.quickSave.favorites),
                              ),
                              ButtonSegment(
                                value: _QuickSaveMode.on,
                                label: Text(t.receiveTab.quickSave.on),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ),
        _InfoBox(vm),
        _CornerButtons(
          showAdvanced: vm.showAdvanced,
          showHistoryButton: vm.showHistoryButton,
          toggleAdvanced: vm.toggleAdvanced,
        ),
      ],
    );
  }
}

class _CornerButtons extends StatelessWidget {
  final bool showAdvanced;
  final bool showHistoryButton;
  final Future<void> Function() toggleAdvanced;

  const _CornerButtons({
    required this.showAdvanced,
    required this.showHistoryButton,
    required this.toggleAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!showAdvanced)
              AnimatedOpacity(
                opacity: showHistoryButton ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: CustomIconButton(
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  child: const Icon(Icons.history_rounded),
                ),
              ),
            CustomIconButton(
              key: const ValueKey('info-btn'),
              onPressed: toggleAdvanced,
              child: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final ReceiveTabVm vm;

  const _InfoBox(this.vm);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedCrossFade(
      crossFadeState: vm.showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      firstChild: Container(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xCC111827) : Colors.white.withValues(alpha: 0.9),
                  border: Border.all(
                    color: isDark ? kGlassBorder : const Color(0x1A000000),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: IntrinsicColumnWidth(),
                      2: IntrinsicColumnWidth(),
                    },
                    children: [
                      TableRow(
                        children: [
                          Text(
                            t.receiveTab.infoBox.alias,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(right: 30),
                            child: SelectableText(vm.serverState?.alias ?? '-'),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Text(
                            t.receiveTab.infoBox.ip,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (vm.localIps.isEmpty) Text(t.general.unknown),
                              ...vm.localIps.map((ip) => SelectableText(ip)),
                            ],
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Text(
                            t.receiveTab.infoBox.port,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SelectableText(vm.serverState?.port.toString() ?? '-'),
                        ],
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
