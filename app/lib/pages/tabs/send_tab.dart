import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/troubleshoot_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/big_button.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/dialogs/add_file_dialog.dart';
import 'package:localsend_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/list_tile/device_placeholder_list_tile.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/responsive_wrap_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

const _horizontalPadding = 15.0;
final _options = FilePickerOption.getOptionsForPlatform();

class SendTab extends StatefulWidget {
  const SendTab();

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  int _selectedFilterTab = 0;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(SendTabInitAction(context)),
      builder: (context, vm) {
        final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
        final buttonWidth = sizingInformation.isDesktop ? BigButton.desktopWidth : BigButton.mobileWidth;
        final ref = context.ref;

        // Both filter tabs show the same nearbyDevices for now;
        // "All Network" could be extended later to include non-LocalSend hosts
        final displayedDevices = vm.nearbyDevices;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kBgDark, kBgDark2],
                ),
              ),
            ),
            ResponsiveListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 20),
                if (vm.selectedFiles.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                    child: Text(
                      t.sendTab.selection.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ResponsiveWrapView(
                    outerHorizontalPadding: 15,
                    outerVerticalPadding: 10,
                    childPadding: 10,
                    minChildWidth: buttonWidth,
                    children: _options.map((option) {
                      return BigButton(
                        icon: option.icon,
                        label: option.label,
                        filled: false,
                        onTap: () async => ref.global.dispatchAsync(
                          PickFileAction(option: option, context: context),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                      left: _horizontalPadding,
                      right: _horizontalPadding,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kGlassFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kGlassBorder, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 15,
                              top: 5,
                              bottom: 15,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.sendTab.selection.title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    CustomIconButton(
                                      onPressed: () => ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction()),
                                      child: Icon(Icons.close, color: kAccentCyan.withOpacity(0.8)),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  t.sendTab.selection.files(files: vm.selectedFiles.length),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                ),
                                Text(
                                  t.sendTab.selection.size(
                                    size: vm.selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize,
                                  ),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: defaultThumbnailSize,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: vm.selectedFiles.length,
                                    itemBuilder: (context, index) {
                                      final file = vm.selectedFiles[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: SmartFileThumbnail.fromCrossFile(file),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () async {
                                        await context.push(() => const SelectedFilesPage());
                                      },
                                      child: Text(t.general.edit),
                                    ),
                                    const SizedBox(width: 15),
                                    _NeonButton(
                                      onPressed: () async {
                                        if (_options.length == 1) {
                                          await ref.global.dispatchAsync(
                                            PickFileAction(option: _options.first, context: context),
                                          );
                                          return;
                                        }
                                        await AddFileDialog.open(context: context, options: _options);
                                      },
                                      icon: Icons.add,
                                      label: t.general.add,
                                    ),
                                    const SizedBox(width: 15),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Devices header row ──────────────────────────────────────
                Row(
                  children: [
                    const SizedBox(width: _horizontalPadding),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          t.sendTab.nearbyDevices,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ScanButton(ips: vm.localIps),
                    Tooltip(
                      message: t.sendTab.manualSending,
                      child: CustomIconButton(
                        onPressed: () async => vm.onTapAddress(context),
                        child: const Icon(Icons.ads_click),
                      ),
                    ),
                    Tooltip(
                      message: t.dialogs.favoriteDialog.title,
                      child: CustomIconButton(
                        onPressed: () async => await vm.onTapFavorite(context),
                        child: const Icon(Icons.favorite),
                      ),
                    ),
                    _SendModeButton(
                      onSelect: (mode) async => vm.onTapSendMode(context, mode),
                    ),
                  ],
                ),

                // ── Filter tabs ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  child: _DeviceFilterTabs(
                    selectedIndex: _selectedFilterTab,
                    onChanged: (i) => setState(() => _selectedFilterTab = i),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Device list ─────────────────────────────────────────────
                if (displayedDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                      left: _horizontalPadding,
                      right: _horizontalPadding,
                    ),
                    child: Opacity(
                      opacity: 0.3,
                      child: const DevicePlaceholderListTile(),
                    ),
                  ),
                ...displayedDevices.map((device) {
                  final favoriteEntry = vm.favoriteDevices.findDevice(device);
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                      left: _horizontalPadding,
                      right: _horizontalPadding,
                    ),
                    child: Hero(
                      tag: 'device-${device.ip}',
                      child: vm.sendMode == SendMode.multiple
                          ? _MultiSendDeviceListTile(
                              device: device,
                              isFavorite: favoriteEntry != null,
                              nameOverride: favoriteEntry?.alias,
                              vm: vm,
                            )
                          : DeviceListTile(
                              device: device,
                              isFavorite: favoriteEntry != null,
                              nameOverride: favoriteEntry?.alias,
                              onFavoriteTap: () async => await vm.onToggleFavorite(context, device),
                              onTap: () async => await vm.onTapDevice(context, device),
                            ),
                    ),
                  );
                }),

                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await context.push(() => const TroubleshootPage());
                    },
                    style: TextButton.styleFrom(foregroundColor: kAccentCyan.withOpacity(0.7)),
                    child: Text(t.troubleshootPage.title),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  child: Consumer(
                    builder: (context, ref) {
                      final animations = ref.watch(animationProvider);
                      return OpacitySlideshow(
                        durationMillis: 6000,
                        running: animations,
                        children: [
                          Text(
                            t.sendTab.help,
                            style: TextStyle(color: Colors.white.withOpacity(0.3)),
                            textAlign: TextAlign.center,
                          ),
                          if (checkPlatformCanReceiveShareIntent())
                            Text(
                              t.sendTab.shareIntentInfo,
                              style: TextStyle(color: Colors.white.withOpacity(0.3)),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
            checkPlatform([TargetPlatform.macOS])
                ? SizedBox(height: 50, child: MoveWindow())
                : const SizedBox(height: 0, width: 0),
          ],
        );
      },
    );
  }
}

/// Glassmorphic filter tab strip for LocalSend / All Network.
class _DeviceFilterTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _DeviceFilterTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['LocalSend', 'All Network'];
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
            children: List.generate(labels.length, (i) {
              final isSelected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [kAccentCyan, kAccentPurple],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kAccentCyan.withOpacity(0.25),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
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

/// A neon-styled elevated button for "Add files".
class _NeonButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _NeonButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [kAccentCyan, kAccentPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: kAccentCyan.withOpacity(0.35), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// A button that opens a popup menu to select [T].
class _CircularPopupButton<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;

  const _CircularPopupButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: Material(
        type: MaterialType.transparency,
        child: DividerTheme(
          data: DividerThemeData(
            color: kGlassBorder,
          ),
          child: PopupMenuButton(
            offset: const Offset(0, 40),
            onSelected: onSelected,
            tooltip: tooltip,
            itemBuilder: itemBuilder,
            color: kSurface,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final List<String> ips;

  const _ScanButton({required this.ips});

  @override
  Widget build(BuildContext context) {
    final (scanningFavorites, scanningIps) =
        context.ref.watch(nearbyDevicesProvider.select((s) => (s.runningFavoriteScan, s.runningIps)));
    final animations = context.ref.watch(animationProvider);

    final spinning = (scanningFavorites || scanningIps.isNotEmpty) && animations;
    final iconColor = !animations && scanningIps.isNotEmpty ? Colors.orangeAccent : kAccentCyan;

    if (ips.length <= StartSmartScan.maxInterfaces) {
      return Tooltip(
        message: t.sendTab.scan,
        child: RotatingWidget(
          duration: const Duration(seconds: 2),
          spinning: spinning,
          reverse: true,
          child: CustomIconButton(
            onPressed: () async {
              context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
              await context.global.dispatchAsync(StartSmartScan(forceLegacy: true));
            },
            child: Icon(Icons.sync, color: iconColor),
          ),
        ),
      );
    }

    return _CircularPopupButton(
      tooltip: t.sendTab.scan,
      onSelected: (ip) async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
      },
      itemBuilder: (_) {
        return [
          ...ips.map(
            (ip) => PopupMenuItem(
              value: ip,
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RotatingSyncIcon(ip),
                  const SizedBox(width: 10),
                  Text(ip, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ];
      },
      child: RotatingWidget(
        duration: const Duration(seconds: 2),
        spinning: spinning,
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.sync, color: iconColor),
        ),
      ),
    );
  }
}

class _RotatingSyncIcon extends StatelessWidget {
  final String ip;

  const _RotatingSyncIcon(this.ip);

  @override
  Widget build(BuildContext context) {
    final scanningIps = context.ref.watch(nearbyDevicesProvider.select((s) => s.runningIps));
    return RotatingWidget(
      duration: const Duration(seconds: 2),
      spinning: scanningIps.contains(ip),
      reverse: true,
      child: const Icon(Icons.sync, color: kAccentCyan),
    );
  }
}

class _SendModeButton extends StatelessWidget {
  final void Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CircularPopupButton<int>(
      tooltip: t.sendTab.sendMode,
      onSelected: (mode) async {
        switch (mode) {
          case 0:
            onSelect(SendMode.single);
            break;
          case 1:
            onSelect(SendMode.multiple);
            break;
          case 2:
            onSelect(SendMode.link);
            break;
          case -1:
            await showDialog(context: context, builder: (_) => const SendModeHelpDialog());
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.single,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle, color: kAccentCyan),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.single, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.multiple,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle, color: kAccentCyan),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.multiple, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Icon(Icons.check_circle, color: kAccentCyan),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.link, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.help, color: kAccentPurple),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModeHelp, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.settings),
      ),
    );
  }
}

/// An advanced list tile which shows the progress of the file transfer.
class _MultiSendDeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final SendTabVm vm;

  const _MultiSendDeviceListTile({
    required this.device,
    required this.isFavorite,
    required this.nameOverride,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final session = ref.watch(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
    final double? progress;
    if (session != null) {
      final files = session.files.values.where((f) => f.token != null);
      final progressNotifier = ref.watch(progressProvider);
      final currBytes = files.fold<int>(
        0,
        (prev, curr) =>
            prev +
            ((progressNotifier.getProgress(sessionId: session.sessionId, fileId: curr.file.id) * curr.file.size).round()),
      );
      final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
      progress = totalBytes == 0 ? 0 : currBytes / totalBytes;
    } else {
      progress = null;
    }
    return DeviceListTile(
      device: device,
      info: session?.status.humanString,
      progress: progress,
      isFavorite: isFavorite,
      nameOverride: nameOverride,
      onFavoriteTap: device.ip == null ? null : () async => await vm.onToggleFavorite(context, device),
      onTap: () async => await vm.onTapDeviceMultiSend(context, device),
    );
  }
}

extension on SessionStatus {
  String? get humanString {
    switch (this) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.sending:
        return null;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
    }
  }
}
