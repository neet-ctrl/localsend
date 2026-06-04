import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/pages/debug/discovery_debug_page.dart';
import 'package:localsend_app/pages/debug/http_logs_page.dart';
import 'package:localsend_app/pages/debug/security_debug_page.dart';
import 'package:localsend_app/provider/app_arguments_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/shared_preferences/shared_preferences_file.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/debug_entry.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appArguments = context.watch(appArgumentsProvider);
    final portableMode = context.watch(persistenceProvider.select((state) => state.isPortableMode()));
    final store = SharedPreferencesStorePlatform.instance;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar('Debugging'),
      body: ListView(
        padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 30),
        children: [
          // Debug entries glass card
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
                    DebugEntry(name: 'Debug Mode', value: kDebugMode.toString()),
                    DebugEntry(name: 'Portable Mode', value: portableMode ? 'true' : 'false'),
                    DebugEntry(name: 'Executable Path', value: Platform.resolvedExecutable),
                    DebugEntry(name: 'Working Directory', value: Directory.current.path),
                    if (store is SharedPreferencesFile)
                      DebugEntry(name: 'Settings Path', value: store.getPath()),
                    DebugEntry(
                      name: 'App Arguments',
                      value: appArguments.isEmpty ? null : appArguments.map((e) => '"$e"').join(' '),
                    ),
                    DebugEntry(name: 'Dart SDK', value: Platform.version),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section label
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [kAccentCyan, kAccentPurple],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const Text('More', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DebugNavButton(
                label: 'Security',
                icon: Icons.security,
                onPressed: () async => context.push(() => const SecurityDebugPage()),
              ),
              _DebugNavButton(
                label: 'Discovery',
                icon: Icons.radar,
                onPressed: () async => context.push(() => const DiscoveryDebugPage()),
              ),
              _DebugNavButton(
                label: 'HTTP Logs',
                icon: Icons.http,
                onPressed: () async => context.push(() => const HttpLogsPage()),
              ),
              if (kDebugMode)
                _DebugNavButton(
                  label: 'Refena Tracing',
                  icon: Icons.timeline,
                  onPressed: () async => context.push(() => const RefenaTracingPage()),
                ),
              _DebugNavButton(
                label: 'Clear Settings',
                icon: Icons.delete_sweep,
                color: Colors.redAccent,
                onPressed: () async => await context.ref.read(persistenceProvider).clear(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _DebugNavButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = kAccentCyan,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
