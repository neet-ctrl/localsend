import 'dart:async';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/pages/hub/hub_chat_page.dart';
import 'package:localsend_app/pages/hub/hub_debug_log_page.dart';
import 'package:localsend_app/pages/hub/hub_remote_files_page.dart';
import 'package:localsend_app/pages/hub/hub_video_call_page.dart';
import 'package:localsend_app/pages/hub/hub_voice_call_page.dart';
import 'package:localsend_app/provider/hub/hub_call_provider.dart';
import 'package:localsend_app/provider/hub/hub_chat_provider.dart';
import 'package:localsend_app/provider/hub/hub_device_history_provider.dart';
import 'package:localsend_app/provider/hub/hub_files_provider.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class CommunicationHubTab extends StatefulWidget {
  const CommunicationHubTab({super.key});

  @override
  State<CommunicationHubTab> createState() => _CommunicationHubTabState();
}

class _CommunicationHubTabState extends State<CommunicationHubTab> with Refena {
  bool _permissionsGranted = false;
  bool _permissionsChecked = false;
  bool _checkingPermissions = false;
  Map<Permission, bool> _permissionStatus = {};
  Timer? _scanTimer;

  final List<Permission> _requiredPermissions = [
    Permission.microphone,
    Permission.camera,
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) Permission.notification,
    if (Platform.isAndroid) Permission.bluetoothConnect,
    if (Platform.isAndroid) Permission.manageExternalStorage,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  void _startContinuousScan() {
    ref.global.dispatchAsync(StartSmartScan(forceLegacy: false));
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.global.dispatchAsync(StartSmartScan(forceLegacy: false));
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checkingPermissions = true);
    final statuses = <Permission, bool>{};
    bool allGranted = true;
    for (final p in _requiredPermissions) {
      try {
        final status = await p.status;
        statuses[p] = status.isGranted;
        if (!status.isGranted) allGranted = false;
      } catch (_) {
        statuses[p] = true;
      }
    }
    setState(() {
      _permissionStatus = statuses;
      _permissionsGranted = allGranted;
      _permissionsChecked = true;
      _checkingPermissions = false;
    });
    if (mounted) _startContinuousScan();
  }

  Future<void> _requestPermissions() async {
    setState(() => _checkingPermissions = true);
    final statuses = await _requiredPermissions.request();
    final map = <Permission, bool>{};
    bool allGranted = true;
    for (final p in _requiredPermissions) {
      final granted = statuses[p]?.isGranted ?? true;
      map[p] = granted;
      if (!granted) allGranted = false;
    }
    setState(() {
      _permissionStatus = map;
      _permissionsGranted = allGranted;
      _checkingPermissions = false;
    });
    if (mounted) _startContinuousScan();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nearbyState = context.watch(nearbyDevicesProvider);
    final chatState = context.watch(hubChatProvider);
    final historyState = context.watch(hubDeviceHistoryProvider);
    context.watch(hubCallProvider);

    // Record every currently-visible device into history
    for (final d in nearbyState.devices.values) {
      ref.notifier(hubDeviceHistoryProvider).sawDevice(d);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: !_permissionsChecked
          ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
          : !_permissionsGranted
          ? _buildPermissionsScreen(isDark)
          : _buildHubContent(context, isDark, nearbyState, chatState, historyState),
    );
  }

  Widget _buildPermissionsScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: kAccentCyan.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [BoxShadow(color: kAccentCyan.withValues(alpha: 0.2), blurRadius: 24)],
              ),
              child: const Icon(Icons.security_rounded, size: 48, color: kAccentCyan),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(colors: [kAccentCyan, Color(0xFF00B8D9)]).createShader(b),
              child: const Text(
                'Permissions Required',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Communication Hub needs the following permissions for calls, messaging, and file access.',
              style: TextStyle(
                color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7FA3),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ..._requiredPermissions.map((p) => _buildPermissionRow(p, isDark)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _checkingPermissions ? null : _requestPermissions,
                icon: _checkingPermissions
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Grant All Permissions'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: kAccentCyan,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _permissionsGranted = true),
              child: const Text('Continue Anyway', style: TextStyle(color: kAccentCyan)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(Permission permission, bool isDark) {
    final granted = _permissionStatus[permission] ?? false;
    final label = _permissionLabel(permission);
    final icon = _permissionIcon(permission);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: granted ? kAccentCyan.withValues(alpha: 0.4) : (isDark ? kGlassBorder : const Color(0x1A000000)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: granted ? kAccentCyan : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black))),
            Icon(
              granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: granted ? kAccentCyan : Colors.red.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(Permission p) {
    if (p == Permission.microphone) return 'Microphone — Voice & Video Calls';
    if (p == Permission.camera) return 'Camera — Video Calls';
    if (p == Permission.notification) return 'Notifications — Incoming Calls & Messages';
    if (p == Permission.bluetoothConnect) return 'Bluetooth — Nearby Device Communication';
    if (p == Permission.manageExternalStorage) return 'Storage — Browse & Download Files';
    return p.toString();
  }

  IconData _permissionIcon(Permission p) {
    if (p == Permission.microphone) return Icons.mic_rounded;
    if (p == Permission.camera) return Icons.videocam_rounded;
    if (p == Permission.notification) return Icons.notifications_rounded;
    if (p == Permission.bluetoothConnect) return Icons.bluetooth_rounded;
    if (p == Permission.manageExternalStorage) return Icons.folder_rounded;
    return Icons.lock_rounded;
  }

  Widget _buildHubContent(
    BuildContext context,
    bool isDark,
    NearbyDevicesState nearbyState,
    HubChatState chatState,
    HubDeviceHistoryState historyState,
  ) {
    final onlineDevices = nearbyState.devices.values.toList();
    final onlineFps = onlineDevices.map((d) => d.fingerprint).toSet();

    // History: devices we've seen before that aren't currently online
    final offlineHistory = historyState.sorted
        .where((h) => !onlineFps.contains(h.fingerprint))
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildDashboardHeader(isDark, onlineDevices, chatState, historyState),

        // ── Online devices ────────────────────────────────────────────────
        if (onlineDevices.isEmpty)
          _buildEmptyState(isDark)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: onlineDevices.map((d) => _DeviceCard(
                device: d,
                unreadCount: chatState.unreadCount(d.fingerprint),
                isDark: isDark,
                isOnline: true,
              )).toList(),
            ),
          ),

        // ── History section ───────────────────────────────────────────────
        if (offlineHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
                const SizedBox(width: 6),
                Text(
                  'Previously Connected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: offlineHistory.map((h) => _HistoryDeviceCard(
                history: h,
                unreadCount: chatState.unreadCount(h.fingerprint),
                isDark: isDark,
                onForget: () => ref.notifier(hubDeviceHistoryProvider).removeDevice(h.fingerprint),
              )).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDashboardHeader(
    bool isDark,
    List<Device> devices,
    HubChatState chatState,
    HubDeviceHistoryState historyState,
  ) {
    final totalUnread = chatState.conversations.keys
        .fold<int>(0, (sum, fp) => sum + chatState.unreadCount(fp));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(colors: [kAccentCyan, Color(0xFF00B8D9)]).createShader(b),
            child: const Text(
              'Communication Hub',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Offline LAN • ${devices.length} device${devices.length != 1 ? 's' : ''} nearby',
            style: TextStyle(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.devices_rounded, label: 'Online', value: '${devices.length}', isDark: isDark)),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Unread',
                  value: '$totalUnread',
                  isDark: isDark,
                  accent: totalUnread > 0 ? kAccentCyan : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.history_rounded,
                  label: 'Known',
                  value: '${historyState.devices.length}',
                  isDark: isDark,
                  accent: historyState.devices.isNotEmpty ? kAccentPurple : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => context.push(() => const HubDebugLogPage()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccentPurple.withValues(alpha: 0.4)),
                        color: kAccentPurple.withValues(alpha: 0.08),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terminal_rounded, size: 14, color: kAccentPurple),
                          SizedBox(width: 4),
                          Text('Logs', style: TextStyle(color: kAccentPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref.global.dispatchAsync(StartSmartScan(forceLegacy: false)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
                        color: kAccentCyan.withValues(alpha: 0.08),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 14, color: kAccentCyan),
                          SizedBox(width: 4),
                          Text('Scan', style: TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF1A2235), Color(0xFF111827)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: kGlassBorder, width: 1),
              ),
              child: Icon(Icons.radar_rounded, size: 56, color: kAccentCyan.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text('No Devices Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text(
              'Make sure other devices have LocalSend open\nand are on the same network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.global.dispatchAsync(StartSmartScan(forceLegacy: false)),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Scan Network'),
              style: FilledButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? accent;

  const _StatCard({required this.icon, required this.label, required this.value, required this.isDark, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent ?? (isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4))),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Online device card
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final Device device;
  final int unreadCount;
  final bool isDark;
  final bool isOnline;

  const _DeviceCard({required this.device, required this.unreadCount, required this.isDark, this.isOnline = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _buildDeviceIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.alias,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kAccentCyan),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _deviceTypeLabel(device.deviceType),
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00E676))),
                            const SizedBox(width: 4),
                            const Text('Online', style: TextStyle(fontSize: 11, color: Color(0xFF00E676))),
                            const SizedBox(width: 12),
                            Text(device.ip ?? '', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _ActionButton(icon: Icons.mic_rounded, label: 'Voice', color: const Color(0xFF00C853), onTap: () => _startVoiceCall(context))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionButton(icon: Icons.videocam_rounded, label: 'Video', color: const Color(0xFF2979FF), onTap: () => _startVideoCall(context))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionButton(icon: Icons.chat_bubble_rounded, label: 'Chat', color: kAccentCyan, onTap: () => _openChat(context), badge: unreadCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionButton(icon: Icons.folder_open_rounded, label: 'Files', color: kAccentPurple, onTap: () => _openFiles(context))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: kAccentCyan.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: kAccentCyan.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Icon(_deviceIcon(device.deviceType), color: kAccentCyan, size: 24),
    );
  }

  IconData _deviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.mobile: return Icons.phone_android_rounded;
      case DeviceType.desktop: return Icons.computer_rounded;
      case DeviceType.web: return Icons.language_rounded;
      case DeviceType.headless: return Icons.dns_rounded;
      case DeviceType.server: return Icons.storage_rounded;
    }
  }

  String _deviceTypeLabel(DeviceType type) {
    switch (type) {
      case DeviceType.mobile: return 'Mobile Device';
      case DeviceType.desktop: return 'Desktop / Laptop';
      case DeviceType.web: return 'Web Browser';
      case DeviceType.headless: return 'Headless Server';
      case DeviceType.server: return 'Server';
    }
  }

  void _startVoiceCall(BuildContext context) {
    context.notifier(hubCallProvider).startCall(device, HubCallType.voice);
    context.push(() => const HubVoiceCallPage());
  }

  void _startVideoCall(BuildContext context) {
    context.notifier(hubCallProvider).startCall(device, HubCallType.video);
    context.push(() => const HubVideoCallPage());
  }

  void _openChat(BuildContext context) {
    context.push(() => HubChatPage(device: device));
  }

  Future<void> _openFiles(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _FilesComingSoonDialog(),
    );
    if (!context.mounted) return;
    if (proceed == true) {
      context.notifier(hubFilesProvider).openDevice(device);
      context.push(() => HubRemoteFilesPage(device: device));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History (offline) device card
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryDeviceCard extends StatelessWidget {
  final HubHistoryDevice history;
  final int unreadCount;
  final bool isDark;
  final VoidCallback onForget;

  const _HistoryDeviceCard({
    required this.history,
    required this.unreadCount,
    required this.isDark,
    required this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final lastSeenDt = DateTime.fromMillisecondsSinceEpoch(history.lastSeen);
    final now = DateTime.now();
    final diff = now.difference(lastSeenDt);
    final lastSeenStr = diff.inMinutes < 60
        ? '${diff.inMinutes}m ago'
        : diff.inHours < 24
            ? '${diff.inHours}h ago'
            : '${diff.inDays}d ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF141C2E), const Color(0xFF0D1220)]
                : [const Color(0xFFF8F9FF), const Color(0xFFEEF2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: isDark ? kGlassBorder.withValues(alpha: 0.5) : const Color(0x12000000)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? const Color(0xFF1A2235) : Colors.white),
                  border: Border.all(color: isDark ? kGlassBorder : const Color(0x15000000)),
                ),
                child: Icon(_deviceIcon(history.deviceType), color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5), size: 22),
              ),
              const SizedBox(width: 12),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            history.alias,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF8899BB) : const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kAccentCyan),
                            child: Text('$unreadCount', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5))),
                        const SizedBox(width: 4),
                        Text('Offline · $lastSeenStr', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chat button
              GestureDetector(
                onTap: () => context.push(() => HubChatPage(device: history.toDevice())),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kAccentCyan.withValues(alpha: 0.1),
                    border: Border.all(color: kAccentCyan.withValues(alpha: 0.3)),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_rounded, color: kAccentCyan, size: 20),
                      if (unreadCount > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccentCyan),
                            child: Center(child: Text('$unreadCount', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Forget button
              GestureDetector(
                onTap: onForget,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.red.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.red.withValues(alpha: 0.6), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _deviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.mobile: return Icons.phone_android_rounded;
      case DeviceType.desktop: return Icons.computer_rounded;
      case DeviceType.web: return Icons.language_rounded;
      case DeviceType.headless: return Icons.dns_rounded;
      case DeviceType.server: return Icons.storage_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button (used in online device card)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccentCyan),
                child: Center(child: Text('$badge', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Coming soon" gate dialog for the Files feature
// ─────────────────────────────────────────────────────────────────────────────

class _FilesComingSoonDialog extends StatefulWidget {
  const _FilesComingSoonDialog();

  @override
  State<_FilesComingSoonDialog> createState() => _FilesComingSoonDialogState();
}

class _FilesComingSoonDialogState extends State<_FilesComingSoonDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onOk() async {
    final value = _controller.text.trim();
    if (value == 'Savan') {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);

    // Capture references before popping — context is invalid after pop.
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    nav.pop(false);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.favorite_rounded, color: kAccentCyan, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Thank you for your comment! We'll review it soon.",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D1220),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF111827), const Color(0xFF0D1220)]
                : [Colors.white, const Color(0xFFF0F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark ? kGlassBorder : const Color(0x1A000000),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: kAccentCyan.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [kAccentCyan.withValues(alpha: 0.18), kAccentPurple.withValues(alpha: 0.18)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: kAccentCyan.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.folder_special_rounded, color: kAccentCyan, size: 32),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              'This feature will be available soon.\nWe\'re working hard to bring it to you!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7FA3),
              ),
            ),
            const SizedBox(height: 28),

            // Divider
            Container(height: 1, color: isDark ? kGlassBorder : const Color(0x1A000000)),
            const SizedBox(height: 24),

            // Comment label
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Leave a comment for us',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Password-style input
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? const Color(0xFF1A2235) : const Color(0xFFF5F7FF),
                border: Border.all(
                  color: isDark ? kGlassBorder : const Color(0x1A000000),
                ),
              ),
              child: TextField(
                controller: _controller,
                obscureText: _obscure,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Your comment…',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _onOk(),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000)),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7FA3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _onOk,
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
