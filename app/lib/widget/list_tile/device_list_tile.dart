import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/device_bage.dart';
import 'package:localsend_app/widget/list_tile/custom_list_tile.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  /// If not null, this name is used instead of [Device.alias].
  /// This is the case when the device is marked as favorite.
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
    final badgeColor = isDark
        ? const Color(0xFF1E2D47)
        : const Color(0xFFDEEAFF);
    final badgeFgColor = isDark ? kAccentCyan : const Color(0xFF1A2235);
    return CustomListTile(
      icon: Icon(device.deviceType.icon, size: 26),
      title: Text(
        nameOverride ?? device.alias,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF0D1220),
          letterSpacing: -0.3,
        ),
      ),
      trailing: onFavoriteTap != null
          ? GestureDetector(
              onTap: onFavoriteTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFavorite
                      ? kAccentCyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: Border.all(
                    color: isFavorite
                        ? kAccentCyan.withValues(alpha: 0.4)
                        : (isDark ? kGlassBorder : const Color(0x15000000)),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? kAccentCyan : (isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
                  size: 18,
                ),
              ),
            )
          : null,
      subTitle: Wrap(
        runSpacing: 8,
        spacing: 8,
        children: [
          if (info != null)
            Text(
              info!,
              style: TextStyle(
                color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
                fontSize: 13,
              ),
            )
          else if (progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: CustomProgressBar(progress: progress!),
            )
          else ...[
            if (device.ip != null)
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: badgeFgColor,
                label: 'LAN • HTTP',
              )
            else
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: badgeFgColor,
                label: 'WebRTC',
              ),
            if (device.deviceModel != null)
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: badgeFgColor,
                label: device.deviceModel!,
              ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
