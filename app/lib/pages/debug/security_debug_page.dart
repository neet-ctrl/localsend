import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/debug_entry.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class SecurityDebugPage extends StatelessWidget {
  const SecurityDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final securityContext = context.ref.watch(securityProvider);
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar('Security Debugging'),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        maxWidth: 700,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.orangeAccent.withOpacity(0.12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 1),
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () async => await context.ref.redux(securityProvider).dispatchAsync(ResetSecurityContextAction()),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: kGlassFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGlassBorder, width: 1),
                ),
                child: Column(
                  children: [
                    DebugEntry(name: 'Certificate SHA-256 (fingerprint)', value: securityContext.certificateHash),
                    DebugEntry(name: 'Certificate', value: securityContext.certificate),
                    DebugEntry(name: 'Private Key', value: securityContext.privateKey),
                    DebugEntry(name: 'Public Key', value: securityContext.publicKey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
