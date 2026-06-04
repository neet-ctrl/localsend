import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/send/web/web_send_state.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ZoomDialog extends StatelessWidget {
  final String label;
  final bool listenIncomingWebSendRequests;
  final String? pin;

  const ZoomDialog({
    required this.label,
    this.listenIncomingWebSendRequests = false,
    this.pin,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * .80;
    final fontSize = width / 400 * 48;

    final WebSendState? webSendState;
    if (listenIncomingWebSendRequests) {
      webSendState = context.ref.watch(serverProvider.select((s) => s?.webSendState));
    } else {
      webSendState = null;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.tv, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.zoom.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // URL displayed large
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kAccentCyan.withOpacity(0.25), width: 1),
                    boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.08), blurRadius: 20)],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: kAccentCyan,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ),
                ),

                if (pin != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kAccentPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kAccentPurple.withOpacity(0.3), width: 1),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.vpn_key, color: kAccentPurple, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            pin!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 40,
                              color: kAccentPurple,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              letterSpacing: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (listenIncomingWebSendRequests && webSendState != null)
                  Builder(
                    builder: (context) {
                      final pending = webSendState?.sessions.values.fold<int>(
                            0,
                            (prev, curr) => prev + (curr.responseHandler != null ? 1 : 0),
                          ) ??
                          0;
                      if (pending != 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1),
                            ),
                            child: Text(
                              t.webSharePage.pendingRequests(n: pending),
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                    onPressed: () => context.pop(),
                    child: Text(t.general.close, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
