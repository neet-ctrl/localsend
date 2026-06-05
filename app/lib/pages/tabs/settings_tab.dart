import 'dart:io';
import 'dart:ui';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/about/about_page.dart';
import 'package:localsend_app/pages/changelog_page.dart';
import 'package:localsend_app/pages/donation/donation_page.dart';
import 'package:localsend_app/pages/language_page.dart';
import 'package:localsend_app/pages/settings/network_interfaces_page.dart';
import 'package:localsend_app/pages/settings/permissions_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/content_uri_helper.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

/// Returns a human-readable label for the save folder setting.
/// Converts Android SAF content:// URIs (e.g. content://...tree/primary%3AAlarms)
/// to a plain folder name (e.g. "Alarms / primary").
/// Falls back to the raw value or the default Downloads label.
String _destinationLabel(String? destination, String downloadsLabel) {
  if (destination == null) return downloadsLabel;
  if (destination.startsWith('content://')) {
    final decoded = ContentUriHelper.getPathFromTreeUri(destination);
    if (decoded != null) {
      // decoded is like "primary:Alarms" or "primary:Downloads/MyFolder"
      final parts = decoded.replaceAll(':', '/').split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length == 1) return parts.first;
      // Show "Storage / Folder" format — last segment is the leaf folder
      return parts.last;
    }
  }
  return destination;
}

class SettingsTab extends StatelessWidget {
  const SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => settingsTabControllerProvider,
      builder: (context, vm) {
        final ref = context.ref;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: MediaQuery.of(context).padding.right,
              ), // So camera or 3-button navigation doesn't interfere on the right, rest is handled
              child: ResponsiveListView(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
                children: [
                  SizedBox(height: 30 + MediaQuery.of(context).padding.top),
                  _PermissionsShortcut(),
                  _SettingsSection(
                    title: t.settingsTab.general.title,
                    children: [
                      _SettingsEntry(
                        label: t.settingsTab.general.brightness,
                        child: CustomDropdownButton<ThemeMode>(
                          value: vm.settings.theme,
                          items: vm.themeModes.map((theme) {
                            return DropdownMenuItem(
                              value: theme,
                              alignment: Alignment.center,
                              child: Text(theme.humanName),
                            );
                          }).toList(),
                          onChanged: (theme) => vm.onChangeTheme(context, theme),
                        ),
                      ),
                      _SettingsEntry(
                        label: t.settingsTab.general.color,
                        child: CustomDropdownButton<ColorMode>(
                          value: vm.settings.colorMode,
                          items: vm.colorModes.map((colorMode) {
                            return DropdownMenuItem(
                              value: colorMode,
                              alignment: Alignment.center,
                              child: Text(colorMode.humanName),
                            );
                          }).toList(),
                          onChanged: vm.onChangeColorMode,
                        ),
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.general.language,
                        buttonLabel: vm.settings.locale?.humanName ?? t.settingsTab.general.languageOptions.system,
                        onTap: () => vm.onTapLanguage(context),
                      ),
                      if (checkPlatformIsDesktop()) ...[
                        /// Wayland does window position handling, so there's no need for it. See [https://github.com/localsend/localsend/issues/544]
                        if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                          _BooleanEntry(
                            label: defaultTargetPlatform == TargetPlatform.windows
                                ? t.settingsTab.general.saveWindowPlacementWindows
                                : t.settingsTab.general.saveWindowPlacement,
                            value: vm.settings.saveWindowPlacement,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setSaveWindowPlacement(b);
                            },
                          ),
                        if (checkPlatformHasTray()) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.minimizeToTray,
                            value: vm.settings.minimizeToTray,
                            onChanged: (b) async {
                              await ref.notifier(settingsProvider).setMinimizeToTray(b);
                            },
                          ),
                        ],
                        if (checkPlatformIsDesktop()) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.launchAtStartup,
                            value: vm.autoStart,
                            onChanged: (_) => vm.onToggleAutoStart(context),
                          ),
                          Visibility(
                            visible: vm.autoStart,
                            maintainAnimation: true,
                            maintainState: true,
                            child: AnimatedOpacity(
                              opacity: vm.autoStart ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 500),
                              child: _BooleanEntry(
                                label: t.settingsTab.general.launchMinimized,
                                value: vm.autoStartLaunchHidden,
                                onChanged: (_) => vm.onToggleAutoStartLaunchHidden(context),
                              ),
                            ),
                          ),
                        ],
                        if (vm.advanced && checkPlatform([TargetPlatform.windows])) ...[
                          _BooleanEntry(
                            label: t.settingsTab.general.showInContextMenu,
                            value: vm.showInContextMenu,
                            onChanged: (_) => vm.onToggleShowInContextMenu(context),
                          ),
                        ],
                      ],
                      _BooleanEntry(
                        label: t.settingsTab.general.animations,
                        value: vm.settings.enableAnimations,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setEnableAnimations(b);
                        },
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: t.settingsTab.receive.title,
                    children: [
                      _BooleanEntry(
                        label: t.settingsTab.receive.quickSave,
                        value: vm.settings.quickSave,
                        onChanged: (b) async {
                          final old = vm.settings.quickSave;
                          await ref.notifier(settingsProvider).setQuickSave(b);
                          if (!old && b && context.mounted) {
                            await QuickSaveNotice.open(context);
                          }
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.quickSaveFromFavorites,
                        value: vm.settings.quickSaveFromFavorites,
                        onChanged: (b) async {
                          final old = vm.settings.quickSaveFromFavorites;
                          await ref.notifier(settingsProvider).setQuickSaveFromFavorites(b);
                          if (!old && b && context.mounted) {
                            await QuickSaveFromFavoritesNotice.open(context);
                          }
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.requirePin,
                        value: vm.settings.receivePin != null,
                        onChanged: (b) async {
                          final currentPIN = vm.settings.receivePin;
                          if (currentPIN != null) {
                            await ref.notifier(settingsProvider).setReceivePin(null);
                          } else {
                            final String? newPin = await showDialog<String>(
                              context: context,
                              builder: (_) => const PinDialog(
                                obscureText: false,
                                generateRandom: false,
                              ),
                            );

                            if (newPin != null && newPin.isNotEmpty) {
                              await ref.notifier(settingsProvider).setReceivePin(newPin);
                            }
                          }
                        },
                      ),
                      if (checkPlatformWithFileSystem())
                        _SettingsEntry(
                          label: t.settingsTab.receive.destination,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Theme.of(context).inputDecorationTheme.fillColor,
                              shape: RoundedRectangleBorder(borderRadius: Theme.of(context).inputDecorationTheme.borderRadius),
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () async {
                              if (vm.settings.destination != null) {
                                await ref.notifier(settingsProvider).setDestination(null);
                                if (defaultTargetPlatform == TargetPlatform.macOS) {
                                  await removeExistingDestinationAccess();
                                }
                                return;
                              }

                              final directory = await pickDirectoryPath();
                              if (directory != null) {
                                if (defaultTargetPlatform == TargetPlatform.macOS) {
                                  await persistDestinationFolderAccess(directory);
                                }
                                await ref.notifier(settingsProvider).setDestination(directory);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text(_destinationLabel(vm.settings.destination, t.settingsTab.receive.downloads), style: Theme.of(context).textTheme.titleMedium),
                            ),
                          ),
                        ),
                      if (checkPlatformWithGallery())
                        _BooleanEntry(
                          label: t.settingsTab.receive.saveToGallery,
                          value: vm.settings.saveToGallery,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setSaveToGallery(b);
                          },
                        ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.autoFinish,
                        value: vm.settings.autoFinish,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setAutoFinish(b);
                        },
                      ),
                      _BooleanEntry(
                        label: t.settingsTab.receive.saveToHistory,
                        value: vm.settings.saveToHistory,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setSaveToHistory(b);
                        },
                      ),
                    ],
                  ),
                  if (vm.advanced)
                    _SettingsSection(
                      title: t.settingsTab.send.title,
                      children: [
                        _BooleanEntry(
                          label: t.settingsTab.send.shareViaLinkAutoAccept,
                          value: vm.settings.shareViaLinkAutoAccept,
                          onChanged: (b) async {
                            await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(b);
                          },
                        ),
                      ],
                    ),
                  _SettingsSection(
                    title: t.settingsTab.network.title,
                    children: [
                      AnimatedCrossFade(
                        crossFadeState:
                            vm.serverState != null &&
                                (vm.serverState!.alias != vm.settings.alias ||
                                    vm.serverState!.port != vm.settings.port ||
                                    vm.serverState!.https != vm.settings.https)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(t.settingsTab.network.needRestart, style: TextStyle(color: Theme.of(context).colorScheme.warning)),
                        ),
                      ),
                      _SettingsEntry(
                        label: '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).inputDecorationTheme.fillColor,
                            borderRadius: Theme.of(context).inputDecorationTheme.borderRadius,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (vm.serverState == null)
                                Tooltip(
                                  message: t.general.start,
                                  child: TextButton(
                                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                    onPressed: () => vm.onTapStartServer(context),
                                    child: const Icon(Icons.play_arrow),
                                  ),
                                )
                              else
                                Tooltip(
                                  message: t.general.restart,
                                  child: TextButton(
                                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                    onPressed: () => vm.onTapRestartServer(context),
                                    child: const Icon(Icons.refresh),
                                  ),
                                ),
                              Tooltip(
                                message: t.general.stop,
                                child: TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                                  onPressed: vm.serverState == null ? null : vm.onTapStopServer,
                                  child: const Icon(Icons.stop),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SettingsEntry(
                        label: t.settingsTab.network.alias,
                        child: TextFieldWithActions(
                          name: t.settingsTab.network.alias,
                          controller: vm.aliasController,
                          onChanged: (s) async {
                            await ref.notifier(settingsProvider).setAlias(s);
                          },
                          actions: [
                            Tooltip(
                              message: t.settingsTab.network.generateRandomAlias,
                              child: IconButton(
                                onPressed: () async {
                                  // Generates random alias
                                  final newAlias = generateRandomAlias();

                                  // Update the TextField with the new alias
                                  vm.aliasController.text = newAlias;

                                  // Persist the new alias using the settingsProvider
                                  await ref.notifier(settingsProvider).setAlias(newAlias);
                                },
                                icon: const Icon(Icons.casino),
                              ),
                            ),
                            Tooltip(
                              message: t.settingsTab.network.useSystemName,
                              child: IconButton(
                                onPressed: () async {
                                  final String newAlias;
                                  if (Platform.isMacOS) {
                                    final result = await Process.run('scutil', ['--get', 'ComputerName']);
                                    newAlias = result.stdout.toString().trim();
                                  } else {
                                    newAlias = Platform.localHostname;
                                  }

                                  vm.aliasController.text = newAlias;
                                  await ref.notifier(settingsProvider).setAlias(newAlias);
                                },
                                icon: const Icon(Icons.desktop_windows_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.deviceType,
                          child: CustomDropdownButton<DeviceType>(
                            value: vm.deviceInfo.deviceType,
                            items: DeviceType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                alignment: Alignment.center,
                                child: Icon(type.icon),
                              );
                            }).toList(),
                            onChanged: (type) async {
                              await ref.notifier(settingsProvider).setDeviceType(type);
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.deviceModel,
                          child: TextFieldTv(
                            name: t.settingsTab.network.deviceModel,
                            controller: vm.deviceModelController,
                            onChanged: (s) async {
                              await ref.notifier(settingsProvider).setDeviceModel(s);
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.port,
                          child: TextFieldTv(
                            name: t.settingsTab.network.port,
                            controller: vm.portController,
                            onChanged: (s) async {
                              final port = int.tryParse(s);
                              if (port != null) {
                                await ref.notifier(settingsProvider).setPort(port);
                              }
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _ButtonEntry(
                          label: t.settingsTab.network.network,
                          buttonLabel: switch (vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null) {
                            true => t.settingsTab.network.networkOptions.filtered,
                            false => t.settingsTab.network.networkOptions.all,
                          },
                          onTap: () async {
                            await context.push(() => const NetworkInterfacesPage());
                          },
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.discoveryTimeout,
                          child: TextFieldTv(
                            name: t.settingsTab.network.discoveryTimeout,
                            controller: vm.timeoutController,
                            onChanged: (s) async {
                              final timeout = int.tryParse(s);
                              if (timeout != null) {
                                await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
                              }
                            },
                          ),
                        ),
                      if (vm.advanced)
                        _BooleanEntry(
                          label: t.settingsTab.network.encryption,
                          value: vm.settings.https,
                          onChanged: (b) async {
                            final old = vm.settings.https;
                            await ref.notifier(settingsProvider).setHttps(b);
                            if (old && !b && context.mounted) {
                              await EncryptionDisabledNotice.open(context);
                            }
                          },
                        ),
                      if (vm.advanced)
                        _SettingsEntry(
                          label: t.settingsTab.network.multicastGroup,
                          child: TextFieldTv(
                            name: t.settingsTab.network.multicastGroup,
                            controller: vm.multicastController,
                            onChanged: (s) async {
                              await ref.notifier(settingsProvider).setMulticastGroup(s);
                            },
                          ),
                        ),
                      AnimatedCrossFade(
                        crossFadeState: vm.settings.port != defaultPort ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            t.settingsTab.network.portWarning(defaultPort: defaultPort),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        crossFadeState: vm.settings.multicastGroup != defaultMulticastGroup ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topLeft,
                        firstChild: Container(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Text(
                            t.settingsTab.network.multicastGroupWarning(defaultMulticast: defaultMulticastGroup),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _SettingsSection(
                    title: t.settingsTab.other.title,
                    padding: const EdgeInsets.only(bottom: 0),
                    children: [
                      _ButtonEntry(
                        label: t.aboutPage.title,
                        buttonLabel: t.general.open,
                        onTap: () async {
                          await context.push(() => const AboutPage());
                        },
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.other.support,
                        buttonLabel: t.settingsTab.other.donate,
                        onTap: () async {
                          await context.push(() => const DonationPage());
                        },
                      ),
                      _ButtonEntry(
                        label: t.settingsTab.other.privacyPolicy,
                        buttonLabel: t.general.open,
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://localsend.org/privacy'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                      if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                        _ButtonEntry(
                          label: t.settingsTab.other.termsOfUse,
                          buttonLabel: t.general.open,
                          onTap: () async {
                            await launchUrl(
                              Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      LabeledCheckbox(
                        label: t.settingsTab.advancedSettings,
                        value: vm.advanced,
                        labelFirst: true,
                        onChanged: (b) async {
                          vm.onTapAdvanced(b == true);
                          await ref.notifier(settingsProvider).setAdvancedSettingsEnabled(b == true);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const LocalSendLogo(withText: true),
                  const SizedBox(height: 5),
                  ref
                      .watch(versionProvider)
                      .maybeWhen(
                        data: (version) => Text(
                          'Version: $version',
                          textAlign: TextAlign.center,
                        ),
                        orElse: () => Container(),
                      ),
                  Text(
                    '© ${DateTime.now().year} Tien Do Nam',
                    textAlign: TextAlign.center,
                  ),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () async {
                        await context.push(() => const ChangelogPage());
                      },
                      icon: const Icon(Icons.history),
                      label: Text(t.changelogPage.title),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            // a pseudo appbar that is draggable for the settings page
            SizedBox(
              height: 50 + MediaQuery.of(context).padding.top,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 20.0,
                    sigmaY: 20.0,
                  ),
                  child: MoveWindow(
                    child: SafeArea(
                      child: Container(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(t.settingsTab.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsEntry({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permissions shortcut card (shown at the top of Settings)
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionsShortcut extends StatefulWidget {
  const _PermissionsShortcut();

  @override
  State<_PermissionsShortcut> createState() => _PermissionsShortcutState();
}

class _PermissionsShortcutState extends State<_PermissionsShortcut> with WidgetsBindingObserver {
  int _total = 0;
  int _granted = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final perms = [
      Permission.microphone,
      Permission.camera,
      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) Permission.notification,
      if (Platform.isAndroid) Permission.bluetoothConnect,
      if (Platform.isAndroid) Permission.manageExternalStorage,
      if (Platform.isAndroid) Permission.ignoreBatteryOptimizations,
    ];
    int granted = 0;
    for (final p in perms) {
      if (await p.isGranted) granted++;
    }
    if (mounted) {
      setState(() {
        _total = perms.length;
        _granted = granted;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allOk = _loaded && _granted == _total;
    final statusColor = allOk ? const Color(0xFF00C853) : const Color(0xFFFFB300);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () async {
          await context.push(() => const PermissionsPage());
          _refresh();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2235), Color(0xFF111827)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFF0F4FF)],
                  ),
            border: Border.all(
              color: allOk
                  ? const Color(0xFF00C853).withValues(alpha: 0.35)
                  : (isDark ? kGlassBorder : const Color(0x1A000000)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: statusColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    allOk ? Icons.verified_rounded : Icons.shield_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permissions',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0D1220),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _loaded
                            ? (allOk ? 'All $_total permissions granted — Hub fully operational' : '$_granted of $_total permissions granted')
                            : 'Checking…',
                        style: TextStyle(
                          color: _loaded
                              ? statusColor
                              : (isDark ? const Color(0xFF8899AA) : const Color(0xFF64748B)),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF4A5568) : const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _BooleanEntry extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanEntry({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _SettingsEntry(
      label: label,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1623) : const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? kGlassBorder : const Color(0x12000000),
                width: 1,
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: kAccentCyan,
                activeThumbColor: kBgDark,
                inactiveThumbColor: theme.colorScheme.outline,
                inactiveTrackColor: theme.colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A specialized version of [_SettingsEntry].
class _ButtonEntry extends StatelessWidget {
  final String label;
  final String buttonLabel;
  final void Function() onTap;

  const _ButtonEntry({
    required this.label,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SettingsEntry(
      label: label,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF0D1623) : const Color(0xFFF0F4FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? kGlassBorder : const Color(0x12000000),
            ),
          ),
          foregroundColor: isDark ? kAccentCyan : const Color(0xFF0D1220),
        ),
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            buttonLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.only(bottom: 15),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2235), Color(0xFF111827)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFF0F4FF)],
                ),
          border: Border.all(
            color: isDark ? kGlassBorder : const Color(0x1A000000),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kAccentCyan, Color(0xFF00B8D9)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
    };
  }
}
