import 'dart:async';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/http_provider.dart';
import 'package:localsend_app/provider/last_devices.provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/rust/api/model.dart';
import 'package:localsend_app/util/rust.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _InputMode {
  hashtag,
  ip;

  String get label {
    return switch (this) {
      _InputMode.hashtag => t.dialogs.addressInput.hashtag,
      _InputMode.ip => t.dialogs.addressInput.ip,
    };
  }
}

/// A dialog to input an hash or address.
/// Pops the dialog with the device if found.
class AddressInputDialog extends StatefulWidget {
  const AddressInputDialog();

  @override
  State<AddressInputDialog> createState() => _AddressInputDialogState();
}

class _AddressInputDialogState extends State<AddressInputDialog> with Refena {
  final _selected = List.generate(_InputMode.values.length, (index) => index == 0);
  _InputMode _mode = _InputMode.hashtag;
  String _input = '';
  bool _fetching = false;
  String? _error;

  Future<void> _submit(List<String> localIps, int port, [String? candidate]) async {
    final List<String> candidates;
    final String input = _input.trim();
    if (candidate != null) {
      candidates = [candidate];
    } else if (_mode == _InputMode.ip) {
      candidates = [input];
    } else {
      candidates = localIps.map((ip) => '${ip.ipPrefix}.$input').toList();
    }

    setState(() => _fetching = true);

    final https = ref.read(settingsProvider).https;

    final deviceCompleter = Completer<void>();
    Device? foundDevice;
    String? error;

    final payload = ref.read(deviceFullInfoProvider).toRegisterDto();

    final List<Future<void>> futures = [
      for (final ip in candidates)
        () async {
          try {
            final response = await ref.read(httpProvider).v2.register(
              protocol: https ? ProtocolType.https : ProtocolType.http,
              ip: ip,
              port: port,
              payload: payload,
            );

            foundDevice = response.body.toDevice(ip, port, https, HttpDiscovery(ip: ip));
            deviceCompleter.complete();
          } catch (e) {
            error = e.toString();
            rethrow;
          }
        }(),
    ];

    try {
      await Future.any([deviceCompleter.future, Future.wait(futures)]);
    } catch (_) {}

    if (!mounted) return;

    if (foundDevice != null) {
      ref.redux(lastDevicesProvider).dispatch(AddLastDeviceAction(foundDevice!));
      context.pop(foundDevice);
    } else {
      setState(() {
        _fetching = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localIps = (ref.watch(localIpProvider.select((info) => info.localIps))).uniqueIpPrefix;
    final settings = ref.watch(settingsProvider);
    final lastDevices = ref.watch(lastDevicesProvider);

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
                      child: const Icon(Icons.wifi_find, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.addressInput.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Mode toggle
                Container(
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kGlassBorder, width: 1),
                  ),
                  child: Row(
                    children: _InputMode.values.mapIndexed((i, mode) {
                      final isSelected = _selected[i];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              for (int j = 0; j < _selected.length; j++) {
                                _selected[j] = j == i;
                              }
                              _mode = _InputMode.values[i];
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              gradient: isSelected
                                  ? const LinearGradient(colors: [kAccentCyan, kAccentPurple])
                                  : null,
                            ),
                            child: Text(
                              mode.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  key: ValueKey('input-$_mode'),
                  autofocus: true,
                  enabled: !_fetching,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: kAccentCyan,
                  keyboardType: _mode == _InputMode.hashtag ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(
                    prefixText: _mode == _InputMode.hashtag ? '# ' : 'IP: ',
                    prefixStyle: TextStyle(color: kAccentCyan.withOpacity(0.7)),
                    hintText: _mode == _InputMode.hashtag ? '123' : '${localIps.firstOrNull?.ipPrefix ?? '192.168.2'}.123',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                  ),
                  onChanged: (s) => setState(() => _input = s),
                  onFieldSubmitted: (s) async => _submit(localIps, settings.port),
                ),

                const SizedBox(height: 10),

                if (_mode == _InputMode.hashtag) ...[
                  Text(
                    '${t.general.example}: 123',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                  ),
                  if (localIps.length <= 1)
                    Text(
                      '${t.dialogs.addressInput.ip}: ${localIps.firstOrNull?.ipPrefix ?? '192.168.2'}.$_input',
                      style: TextStyle(color: kAccentCyan.withOpacity(0.5), fontSize: 12, fontFamily: 'RobotoMono'),
                    )
                  else ...[
                    Text('${t.dialogs.addressInput.ip}:', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                    for (final ip in localIps)
                      Text('- ${ip.ipPrefix}.$_input', style: TextStyle(color: kAccentCyan.withOpacity(0.5), fontSize: 12, fontFamily: 'RobotoMono')),
                  ],
                ] else ...[
                  if (lastDevices.isEmpty)
                    Text(
                      '${t.general.example}: ${localIps.firstOrNull?.ipPrefix ?? '192.168.2'}.123',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                    )
                  else
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: t.dialogs.addressInput.recentlyUsed,
                            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
                          ),
                          ...lastDevices.mapIndexed((index, device) {
                            return [
                              if (index != 0) TextSpan(text: ', ', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                              TextSpan(
                                text: device.ip,
                                style: const TextStyle(color: kAccentCyan, fontSize: 12, fontFamily: 'RobotoMono'),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () async => _submit(localIps, settings.port, device.ip),
                              ),
                            ];
                          }).expand((e) => e),
                        ],
                      ),
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

                const SizedBox(height: 20),
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
                        onPressed: _fetching ? null : () async => _submit(localIps, settings.port),
                        child: _fetching
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
    );
  }
}

extension on String {
  String get ipPrefix {
    return split('.').take(3).join('.');
  }
}

extension on List<String> {
  List<String> get uniqueIpPrefix {
    final seen = <String>{};
    return where((s) => seen.add(s.ipPrefix)).toList();
  }
}
