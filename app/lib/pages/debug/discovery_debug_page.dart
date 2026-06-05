import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/widget/copyable_text.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _dateFormat = DateFormat.Hms();

class DiscoveryDebugPage extends StatelessWidget {
  const DiscoveryDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final logs = ref.watch(discoveryLoggerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: basicLocalSendAppbar('Discovery Debugging'),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () => ref.redux(nearbyDevicesProvider).dispatch(StartMulticastScan()),
                child: const Text('Announce'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? kGlassFill : const Color(0xFFF0F4FF),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0D1220),
                ),
                onPressed: () => ref.notifier(discoveryLoggerProvider).clear(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...logs.map(
            (log) => CopyableText(
              prefix: TextSpan(
                text: '[${_dateFormat.format(log.timestamp)}] ',
                style: const TextStyle(
                  color: Color(0xFF00BFA5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              name: log.log,
              value: log.log,
            ),
          ),
        ],
      ),
    );
  }
}
