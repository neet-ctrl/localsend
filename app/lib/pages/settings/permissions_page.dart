import 'dart:io';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:permission_handler/permission_handler.dart';

/// A full, persistent screen showing every runtime permission and the
/// battery-optimization exemption (background service). Accessible from the
/// Settings tab. Refreshes status automatically on open and after each grant.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  late final List<_PermEntry> _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entries = _buildEntries();
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user comes back from the system settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  List<_PermEntry> _buildEntries() {
    return [
      _PermEntry(
        permission: Permission.microphone,
        icon: Icons.mic_rounded,
        label: 'Microphone',
        description: 'Required for voice & video calls in the Hub.',
      ),
      _PermEntry(
        permission: Permission.camera,
        icon: Icons.videocam_rounded,
        label: 'Camera',
        description: 'Required for video calls in the Hub.',
      ),
      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)
        _PermEntry(
          permission: Permission.notification,
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          description: 'Required for incoming call & message alerts.',
        ),
      if (Platform.isAndroid)
        _PermEntry(
          permission: Permission.bluetoothConnect,
          icon: Icons.bluetooth_rounded,
          label: 'Bluetooth',
          description: 'Required for the Hub foreground service on Android 12+.',
        ),
      if (Platform.isAndroid)
        _PermEntry(
          permission: Permission.storage,
          icon: Icons.folder_rounded,
          label: 'Storage',
          description: 'Required to browse and download shared files.',
        ),
      if (Platform.isAndroid)
        _PermEntry(
          permission: Permission.ignoreBatteryOptimizations,
          icon: Icons.battery_charging_full_rounded,
          label: 'Background Service',
          description: 'Exempts the Hub from battery optimisation so it stays reachable when the screen is off.',
        ),
    ];
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    for (final e in _entries) {
      e.status = await e.permission.status;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _requestOne(_PermEntry entry) async {
    PermissionStatus result;
    if (entry.permission == Permission.ignoreBatteryOptimizations) {
      result = await entry.permission.request();
    } else {
      result = await entry.permission.request();
    }
    entry.status = result;
    if (mounted) setState(() {});

    // If permanently denied, offer to open system settings.
    if (result.isPermanentlyDenied && mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            '"${entry.label}" was permanently denied. Open app settings to enable it manually.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Settings')),
          ],
        ),
      );
      if (open == true) await openAppSettings();
    }
  }

  Future<void> _grantAllMissing() async {
    for (final e in _entries) {
      if (!(e.status?.isGranted ?? false)) {
        await _requestOne(e);
      }
    }
  }

  bool get _allGranted => _entries.every((e) => e.status?.isGranted ?? false);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Permissions'),
        backgroundColor: isDark ? kBgDark : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0D1220),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // ── Overall status banner ──────────────────────────────────
                _StatusBanner(allGranted: _allGranted, isDark: isDark, cs: cs),
                const SizedBox(height: 20),

                // ── Permission cards ───────────────────────────────────────
                ...List.generate(_entries.length, (i) {
                  final entry = _entries[i];
                  final granted = entry.status?.isGranted ?? false;
                  final permanentlyDenied = entry.status?.isPermanentlyDenied ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PermissionCard(
                      entry: entry,
                      granted: granted,
                      permanentlyDenied: permanentlyDenied,
                      isDark: isDark,
                      cs: cs,
                      onGrant: () => _requestOne(entry),
                      onOpenSettings: openAppSettings,
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // ── Grant All button ───────────────────────────────────────
                if (!_allGranted)
                  FilledButton.icon(
                    onPressed: _grantAllMissing,
                    icon: const Icon(Icons.shield_rounded, size: 18),
                    label: const Text('Grant All Missing Permissions'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('All Permissions Granted'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFF00C853).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF00C853),
                      disabledBackgroundColor: const Color(0xFF00C853).withValues(alpha: 0.15),
                      disabledForegroundColor: const Color(0xFF00C853),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _PermEntry {
  final Permission permission;
  final IconData icon;
  final String label;
  final String description;
  PermissionStatus? status;

  _PermEntry({
    required this.permission,
    required this.icon,
    required this.label,
    required this.description,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final bool allGranted;
  final bool isDark;
  final ColorScheme cs;

  const _StatusBanner({required this.allGranted, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = allGranted ? const Color(0xFF00C853) : const Color(0xFFFFB300);
    final bg = color.withValues(alpha: isDark ? 0.12 : 0.10);
    final icon = allGranted ? Icons.verified_rounded : Icons.warning_amber_rounded;
    final title = allGranted ? 'All systems go' : 'Action required';
    final subtitle = allGranted
        ? 'Every permission is granted. The Hub and all its features are fully operational.'
        : 'One or more permissions are missing. Tap Grant below each item or use Grant All.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final _PermEntry entry;
  final bool granted;
  final bool permanentlyDenied;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  const _PermissionCard({
    required this.entry,
    required this.granted,
    required this.permanentlyDenied,
    required this.isDark,
    required this.cs,
    required this.onGrant,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = granted ? const Color(0xFF00C853) : const Color(0xFFFF4D6D);
    final statusLabel = granted ? 'Granted' : (permanentlyDenied ? 'Denied' : 'Not granted');
    final statusIcon = granted ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kCardSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: granted
              ? const Color(0xFF00C853).withValues(alpha: 0.25)
              : (isDark ? kGlassBorder : const Color(0x1A000000)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Icon container ─────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: (granted ? const Color(0xFF00C853) : kAccentCyan).withValues(alpha: 0.12),
              ),
              child: Icon(
                entry.icon,
                size: 22,
                color: granted ? const Color(0xFF00C853) : kAccentCyan,
              ),
            ),
            const SizedBox(width: 14),

            // ── Labels ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0D1220),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF8899AA) : const Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Status chip ──────────────────────────────────────────
                  Row(
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Action button ──────────────────────────────────────────────
            if (!granted) ...[
              const SizedBox(width: 10),
              Column(
                children: [
                  if (permanentlyDenied)
                    _ActionChip(
                      label: 'Settings',
                      icon: Icons.open_in_new_rounded,
                      onTap: onOpenSettings,
                      isDark: isDark,
                    )
                  else
                    _ActionChip(
                      label: 'Grant',
                      icon: Icons.lock_open_rounded,
                      onTap: onGrant,
                      isDark: isDark,
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF00C853)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kAccentCyan, Color(0xFF00B8D9)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: kAccentCyan.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kBgDark),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: kBgDark,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
