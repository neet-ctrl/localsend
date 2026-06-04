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
import 'package:localsend_app/widget/dialogs/favorite_delete_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

/// A dialog to add or edit a favorite device.
class FavoriteEditDialog extends StatefulWidget {
  final FavoriteDevice? favorite;
  final Device? prefilledDevice;

  const FavoriteEditDialog({
    this.favorite,
    this.prefilledDevice,
  });

  @override
  State<FavoriteEditDialog> createState() => _FavoriteEditDialogState();
}

class _FavoriteEditDialogState extends State<FavoriteEditDialog> with Refena {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _aliasController = TextEditingController();
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.prefilledDevice?.ip ?? widget.favorite?.ip ?? '';
    _aliasController.text = widget.prefilledDevice?.alias ?? widget.favorite?.alias ?? '';

    ensureRef((ref) {
      _portController.text = widget.prefilledDevice?.port.toString() ??
          widget.favorite?.port.toString() ??
          ref.read(settingsProvider).port.toString();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.favorite != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        isEditing ? t.dialogs.favoriteEditDialog.titleEdit : t.dialogs.favoriteEditDialog.titleAdd,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _FieldLabel(t.dialogs.favoriteEditDialog.name),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _aliasController,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: kAccentCyan,
                    decoration: InputDecoration(hintText: t.dialogs.favoriteEditDialog.auto),
                    enabled: !_fetching,
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel(t.dialogs.favoriteEditDialog.ip),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                    cursorColor: kAccentCyan,
                    autofocus: !isEditing && widget.prefilledDevice == null,
                    enabled: !_fetching,
                  ),

                  const SizedBox(height: 16),
                  _FieldLabel(t.dialogs.favoriteEditDialog.port),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _portController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                    cursorColor: kAccentCyan,
                    enabled: !_fetching,
                    keyboardType: TextInputType.number,
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (_) => FavoriteDeleteDialog(widget.favorite!),
                        );
                        if (context.mounted && result == true) {
                          await context.ref
                              .redux(favoritesProvider)
                              .dispatchAsync(RemoveFavoriteAction(deviceFingerprint: widget.favorite!.fingerprint));
                          if (context.mounted) context.pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(t.general.delete),
                    ),
                  ],

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Text(t.general.error, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                          const SizedBox(width: 5),
                          InkWell(
                            onTap: () async {
                              await showDialog(context: context, builder: (_) => ErrorDialog(error: _error!));
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.info, color: Colors.orangeAccent, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.55)),
                        onPressed: () => context.pop(),
                        child: Text(t.general.cancel),
                      ),
                      const SizedBox(width: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: _fetching
                              ? null
                              : () async {
                                  if (_ipController.text.isEmpty || _portController.text.isEmpty) return;

                                  if (isEditing) {
                                    final existingFavorite = widget.favorite!;
                                    final trimmedNewAlias = _aliasController.text.trim();
                                    if (trimmedNewAlias.isEmpty) return;

                                    await ref.redux(favoritesProvider).dispatchAsync(
                                      UpdateFavoriteAction(
                                        existingFavorite.copyWith(
                                          ip: _ipController.text,
                                          port: int.parse(_portController.text),
                                          alias: trimmedNewAlias,
                                          customAlias: existingFavorite.customAlias || trimmedNewAlias != existingFavorite.alias,
                                        ),
                                      ),
                                    );
                                    if (context.mounted) context.pop();
                                  } else {
                                    final ip = _ipController.text;
                                    final port = int.parse(_portController.text);
                                    final https = ref.read(settingsProvider).https;
                                    setState(() => _fetching = true);

                                    try {
                                      final payload = ref.read(deviceFullInfoProvider).toRegisterDto();
                                      final response = await ref.read(httpProvider).v2.register(
                                        protocol: https ? ProtocolType.https : ProtocolType.http,
                                        ip: ip,
                                        port: port,
                                        payload: payload,
                                      );

                                      final name = _aliasController.text.trim();
                                      await ref.redux(favoritesProvider).dispatchAsync(
                                        AddFavoriteAction(
                                          FavoriteDevice.fromValues(
                                            fingerprint: response.body.token,
                                            ip: _ipController.text,
                                            port: int.parse(_portController.text),
                                            alias: name.isEmpty ? response.body.alias : name,
                                          ),
                                        ),
                                      );

                                      if (context.mounted) context.pop();
                                    } catch (e) {
                                      setState(() {
                                        _fetching = false;
                                        _error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: _fetching
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(t.general.confirm, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.w600));
  }
}
