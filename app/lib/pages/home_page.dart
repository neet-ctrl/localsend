import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/model/hub/hub_message.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/hub/hub_video_call_page.dart';
import 'package:localsend_app/pages/hub/hub_voice_call_page.dart';
import 'package:localsend_app/pages/tabs/communication_hub_tab.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/hub/hub_call_provider.dart';
import 'package:localsend_app/provider/hub/hub_chat_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.wifi_rounded),
  send(Icons.send_rounded),
  communicationHub(Icons.hub_rounded),
  settings(Icons.settings_rounded);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.communicationHub:
        return 'Hub';
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  // Call overlay tracking
  HubCallStatus? _prevCallStatus;
  bool _callOverlayShown = false;

  // Chat notification tracking
  bool _chatReady = false;
  int _prevTotalUnread = 0;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
      // Allow a warm-up period before showing chat notifications so
      // persisted unread counts don't fire false banners on startup.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _chatReady = true);
    });
  }

  // ── Call overlay ──────────────────────────────────────────────────────────

  void _handleCallState(BuildContext context, HubCallState callState) {
    final isNewIncoming = callState.status == HubCallStatus.incoming &&
        _prevCallStatus != HubCallStatus.incoming &&
        !_callOverlayShown;

    if (isNewIncoming) {
      _callOverlayShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final page = callState.type == HubCallType.video
            ? const HubVideoCallPage()
            : const HubVoiceCallPage();
        Navigator.of(context, rootNavigator: true)
            .push(
              PageRouteBuilder<void>(
                fullscreenDialog: true,
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (ctx, animation, _) => FadeTransition(
                  opacity: animation,
                  child: page,
                ),
              ),
            )
            .then((_) => _callOverlayShown = false);
      });
    }

    // Reset flag when call becomes idle/ended so next call works
    if (callState.status == HubCallStatus.idle ||
        callState.status == HubCallStatus.ended) {
      _callOverlayShown = false;
    }

    _prevCallStatus = callState.status;
  }

  // ── Chat banner ───────────────────────────────────────────────────────────

  void _handleChatState(BuildContext context, HubChatState chatState, HomeTab currentTab) {
    final totalUnread = chatState.conversations.keys
        .fold<int>(0, (sum, fp) => sum + chatState.unreadCount(fp));

    if (_chatReady && totalUnread > _prevTotalUnread && currentTab != HomeTab.communicationHub) {
      // Find the latest unread message to show in the banner
      String senderAlias = 'New message';
      String preview = '';
      int latestTs = 0;
      for (final fp in chatState.conversations.keys) {
        final unread = chatState.messagesFor(fp)
            .where((m) => !m.read && m.senderFingerprint == fp);
        for (final msg in unread) {
          if (msg.timestamp > latestTs) {
            latestTs = msg.timestamp;
            senderAlias = msg.senderAlias;
            preview = msg.type == HubMessageType.text
                ? msg.content
                : '📎 ${msg.fileName ?? 'File'}';
          }
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF0D1220),
            content: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentCyan.withValues(alpha: 0.15),
                    border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: kAccentCyan, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderAlias,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        preview,
                        style: const TextStyle(color: Color(0xFF8899BB), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });
    }

    _prevTotalUnread = totalUnread;
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch hub state for overlay + banner triggers
    final callState = context.watch(hubCallProvider);
    final chatState = context.watch(hubChatProvider);
    _handleCallState(context, callState);
    _handleChatState(context, chatState, vm.currentTab);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        if (event.files.length == 1 && Directory(event.files.first.path).existsSync()) {
          // user dropped a directory
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(event.files.first.path));
        } else {
          // user dropped one or more files
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: event.files,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          return Scaffold(
            body: Row(
              children: [
                if (!sizingInformation.isMobile)
                  Stack(
                    children: [
                      NavigationRail(
                        selectedIndex: vm.currentTab.index,
                        onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                        extended: sizingInformation.isDesktop,
                        backgroundColor: Theme.of(context).cardColorWithElevation,
                        leading: sizingInformation.isDesktop
                            ? Column(
                                children: [
                                  checkPlatform([TargetPlatform.macOS])
                                      ? // considered adding some extra space so it looks more natural
                                        SizedBox(height: 40)
                                      : SizedBox(height: 20),
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [kAccentCyan, Color(0xFF00B8D9)],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'LocalSend',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                ],
                              )
                            : checkPlatform([TargetPlatform.macOS])
                            ? SizedBox(
                                height: 20,
                              )
                            : null,
                        destinations: HomeTab.values.map((tab) {
                          return NavigationRailDestination(
                            icon: Icon(tab.icon),
                            label: Text(tab.label),
                          );
                        }).toList(),
                      ),
                      // makes the top draggable
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: MoveWindow(),
                      ),
                    ],
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView(
                        controller: vm.controller,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          SafeArea(child: ReceiveTab()),
                          SafeArea(child: SendTab()),
                          SafeArea(child: CommunicationHubTab()),
                          SettingsTab(),
                        ],
                      ),
                      if (_dragAndDropIndicator)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kAccentCyan.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: kAccentCyan.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kAccentCyan.withValues(alpha: 0.2),
                                      blurRadius: 40,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.file_download_rounded, size: 64, color: kAccentCyan),
                              ),
                              const SizedBox(height: 30),
                              Text(
                                t.sendTab.placeItems,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0D1220),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: sizingInformation.isMobile
                ? NavigationBar(
                    selectedIndex: vm.currentTab.index,
                    onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                    destinations: HomeTab.values.map((tab) {
                      return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
                    }).toList(),
                  )
                : null,
          );
        },
      ),
    );
  }
}
