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

    return Stack(
      children: [
        // Dark space gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [
                Color(0xFF0D1A2E),
                kBgDark,
              ],
            ),
          ),
        ),

        // macOS drag region
        checkPlatform([TargetPlatform.macOS])
            ? SizedBox(height: 50, child: MoveWindow())
            : const SizedBox(height: 0, width: 0),

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
                        // Glowing rotating logo
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 200),
                          child: Consumer(
                            builder: (context, ref) {
                              final animations = ref.watch(animationProvider);
                              final activeTab = ref.watch(
                                homePageControllerProvider.select((state) => state.currentTab),
                              );
                              final isSpinning =
                                  vm.serverState != null && animations && activeTab == HomeTab.receive;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow ring
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: kAccentCyan.withOpacity(isSpinning ? 0.30 : 0.10),
                                          blurRadius: isSpinning ? 60 : 30,
                                          spreadRadius: isSpinning ? 10 : 4,
                                        ),
                                        BoxShadow(
                                          color: kAccentPurple.withOpacity(isSpinning ? 0.20 : 0.06),
                                          blurRadius: isSpinning ? 80 : 20,
                                          spreadRadius: isSpinning ? 6 : 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Glass circle backdrop
                                  ClipOval(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: kGlassFill,
                                          border: Border.all(color: kGlassBorder, width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Rotating logo
                                  RotatingWidget(
                                    duration: const Duration(seconds: 15),
                                    spinning: isSpinning,
                                    child: const LocalSendLogo(withText: false),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Device alias
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFCCEEFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              vm.serverState?.alias ?? vm.aliasSettings,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // IP / offline status
                        InitialFadeTransition(
                          duration: const Duration(milliseconds: 300),
                          delay: const Duration(milliseconds: 500),
                          child: vm.serverState == null
                              ? _NeonStatusChip(
                                  label: t.general.offline,
                                  color: Colors.redAccent,
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.center,
                                  children: vm.localIps
                                      .map((ip) => ip.visualId)
                                      .toSet()
                                      .map((id) => _NeonStatusChip(
                                            label: '#$id',
                                            color: kAccentCyan,
                                          ))
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Quick save controls
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            t.general.quickSave,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _GlassSegmentedButton(
                            selected: {
                              if (!vm.quickSaveSettings && !vm.quickSaveFromFavoritesSettings) _QuickSaveMode.off,
                              if (vm.quickSaveFromFavoritesSettings) _QuickSaveMode.favorites,
                              if (vm.quickSaveSettings) _QuickSaveMode.on,
                            },
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

/// A glassmorphic segmented button replacing the default Material one.
class _GlassSegmentedButton extends StatelessWidget {
  final Set<_QuickSaveMode> selected;
  final ValueChanged<Set<_QuickSaveMode>> onSelectionChanged;

  const _GlassSegmentedButton({
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = _QuickSaveMode.values;
    final labels = [
      t.receiveTab.quickSave.off,
      t.receiveTab.quickSave.favorites,
      t.receiveTab.quickSave.on,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: kGlassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGlassBorder, width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(modes.length, (i) {
              final mode = modes[i];
              final isSelected = selected.contains(mode);
              return GestureDetector(
                onTap: () => onSelectionChanged({mode}),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [kAccentCyan, kAccentPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kAccentCyan.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Small chip used to display IP / offline status.
class _NeonStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _NeonStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
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
                child: _GlassIconButton(
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  icon: Icons.history,
                ),
              ),
            _GlassIconButton(
              key: const ValueKey('info-btn'),
              onPressed: toggleAdvanced,
              icon: Icons.info_outline,
              accentColor: showAdvanced ? kAccentCyan : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small glass-framed icon button used in the top-right corner.
class _GlassIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? accentColor;

  const _GlassIconButton({
    required this.onPressed,
    required this.icon,
    this.accentColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Colors.white.withOpacity(0.55);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kGlassFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor?.withOpacity(0.5) ?? kGlassBorder,
                  width: 1,
                ),
                boxShadow: accentColor != null
                    ? [BoxShadow(color: accentColor!.withOpacity(0.25), blurRadius: 8)]
                    : null,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
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
    return AnimatedCrossFade(
      crossFadeState: vm.showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      firstChild: Container(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: kGlassFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGlassBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: IntrinsicColumnWidth(),
                      2: IntrinsicColumnWidth(),
                    },
                    children: [
                      _infoRow(
                        context,
                        label: t.receiveTab.infoBox.alias,
                        value: vm.serverState?.alias ?? '-',
                      ),
                      _infoRow(
                        context,
                        label: t.receiveTab.infoBox.ip,
                        value: vm.localIps.isEmpty ? t.general.unknown : vm.localIps.join('\n'),
                        selectable: true,
                      ),
                      _infoRow(
                        context,
                        label: t.receiveTab.infoBox.port,
                        value: vm.serverState?.port.toString() ?? '-',
                        selectable: true,
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

  TableRow _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    bool selectable = false,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(right: 30, bottom: 6),
          child: selectable
              ? SelectableText(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                )
              : Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
        ),
      ],
    );
  }
}
