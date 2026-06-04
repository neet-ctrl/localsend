import 'dart:ui';

import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/device_bage.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  /// If not null, this name is used instead of [Device.alias].
  final String? nameOverride;

  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: _GlassCard(
        isDark: isDark,
        child: Row(
          children: [
            _DeviceIconBox(deviceType: device.deviceType, isDark: isDark),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nameOverride ?? device.alias,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0D1220),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _SubtitleContent(
                    device: device,
                    info: info,
                    progress: progress,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            if (onFavoriteTap != null)
              _FavoriteButton(
                isFavorite: isFavorite,
                onTap: onFavoriteTap!,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (!isDark) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2235).withValues(alpha: 0.85),
                const Color(0xFF0D1627).withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kGlassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: kAccentCyan.withValues(alpha: 0.04),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DeviceIconBox extends StatelessWidget {
  final DeviceType deviceType;
  final bool isDark;

  const _DeviceIconBox({required this.deviceType, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentCyan.withValues(alpha: 0.18),
                  kAccentPurple.withValues(alpha: 0.18),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentCyan.withValues(alpha: 0.12),
                  kAccentPurple.withValues(alpha: 0.12),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? kAccentCyan.withValues(alpha: 0.25) : kAccentCyan.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        deviceType.icon,
        size: 28,
        color: isDark ? kAccentCyan : const Color(0xFF006B82),
      ),
    );
  }
}

class _SubtitleContent extends StatelessWidget {
  final Device device;
  final String? info;
  final double? progress;
  final bool isDark;

  const _SubtitleContent({
    required this.device,
    required this.info,
    required this.progress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (info != null) {
      return Text(
        info!,
        style: TextStyle(
          color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
          fontSize: 13,
        ),
      );
    }

    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CustomProgressBar(progress: progress!),
      );
    }

    return Wrap(
      runSpacing: 6,
      spacing: 6,
      children: [
        _NeonBadge(
          label: device.ip != null ? 'LAN • HTTP' : 'WebRTC',
          isDark: isDark,
        ),
        if (device.deviceModel != null)
          _NeonBadge(
            label: device.deviceModel!,
            isDark: isDark,
            secondary: true,
          ),
      ],
    );
  }
}

class _NeonBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool secondary;

  const _NeonBadge({
    required this.label,
    required this.isDark,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = secondary ? kAccentPurple : kAccentCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? accent.withValues(alpha: 0.10) : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? accent.withValues(alpha: 0.35) : accent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? accent : (secondary ? kAccentPurple : const Color(0xFF006B82)),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final bool isDark;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isFavorite
              ? kAccentPurple.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isFavorite
              ? Border.all(color: kAccentPurple.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: isFavorite
              ? kAccentPurple
              : (isDark ? const Color(0xFF4A5568) : const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }
}
