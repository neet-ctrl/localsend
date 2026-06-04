import 'dart:ui';

import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/http_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/rust/api/model.dart';
import 'package:localsend_app/util/rust.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/dialogs/favorite_edit_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// A dialog showing a list of favorites
class FavoritesDialog extends StatefulWidget {
  const FavoritesDialog();

  @override
  State<FavoritesDialog> createState() => _FavoritesDialogState();
}

class _FavoritesDialogState extends State<FavoritesDialog> with Refena {
  bool _fetching = false;
  String? _error;

  Future<void> _checkConnectionToDevice(FavoriteDevice favorite) async {
    setState(() => _fetching = true);

    final https = ref.read(settingsProvider).https;

    try {
      final payload = ref.read(deviceFullInfoProvider).toRegisterDto();
      final response = await ref.read(httpProvider).v2.register(
        protocol: https ? ProtocolType.https : ProtocolType.http,
        ip: favorite.ip,
        port: favorite.port,
        payload: payload,
      );

      final device = response.body.toDevice(favorite.ip, favorite.port, https, HttpDiscovery(ip: favorite.ip));

      if (mounted) context.pop(device);
    } catch (e) {
      setState(() {
        _fetching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showDeviceDialog([FavoriteDevice? favorite]) async {
    await showDialog(
      context: context,
      builder: (_) => FavoriteEditDialog(favorite: favorite),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.favoriteDialog.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // List
                if (favorites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        t.dialogs.favoriteDialog.noFavorites,
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 14),
                      ),
                    ),
                  ),

                for (final favorite in favorites)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kGlassFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGlassBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onPressed: _fetching ? null : () async => await _checkConnectionToDevice(favorite),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      favorite.alias,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      favorite.ip,
                                      style: TextStyle(color: kAccentCyan.withOpacity(0.7), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: kAccentCyan, size: 18),
                              onPressed: _fetching ? null : () async => await _showDeviceDialog(favorite),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Text(t.general.error, style: const TextStyle(color: Colors.orangeAccent)),
                        const SizedBox(width: 5),
                        InkWell(
                          onTap: () async {
                            await showDialog(
                              context: context,
                              builder: (_) => ErrorDialog(error: _error!),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(Icons.info, color: Colors.orangeAccent, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.55)),
                      onPressed: () => context.pop(),
                      child: Text(t.general.cancel),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                        boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _showDeviceDialog,
                        child: Text(t.dialogs.favoriteDialog.addFavorite, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
