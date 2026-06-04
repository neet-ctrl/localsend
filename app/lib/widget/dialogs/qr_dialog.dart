import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/send/web/web_send_state.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class QrDialog extends StatelessWidget {
  final String data;
  final String? label;
  final bool listenIncomingWebSendRequests;
  final String? pin;

  const QrDialog({
    required this.data,
    this.label,
    this.listenIncomingWebSendRequests = false,
    this.pin,
  });

  @override
  Widget build(BuildContext context) {
    final WebSendState? webSendState;
    if (listenIncomingWebSendRequests) {
      webSendState = context.ref.watch(serverProvider.select((s) => s?.webSendState));
    } else {
      webSendState = null;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
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
                      child: const Icon(Icons.qr_code, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.qr.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // QR code with glow border
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: kAccentCyan.withOpacity(0.25), blurRadius: 24, spreadRadius: 2),
                    ],
                  ),
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: PrettyQrView.data(
                      errorCorrectLevel: QrErrorCorrectLevel.Q,
                      data: data,
                      decoration: const PrettyQrDecoration(
                        shape: PrettyQrSmoothSymbol(
                          roundFactor: 0.5,
                          color: Color(0xFF0A0E1A),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (label != null)
                  Text(
                    label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kAccentCyan.withOpacity(0.8), fontSize: 13, fontFamily: 'RobotoMono'),
                  ),

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
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.4), width: 1),
                            ),
                            child: Text(
                              t.webSharePage.pendingRequests(n: pending),
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                if (pin != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: kAccentPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccentPurple.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key, color: kAccentPurple, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          pin!,
                          style: const TextStyle(
                            color: kAccentPurple,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            fontFamily: 'RobotoMono',
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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
