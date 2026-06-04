import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/provider/logging/http_logs_provider.dart';
import 'package:localsend_app/widget/copyable_text.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _dateFormat = DateFormat.Hms();

class HttpLogsPage extends StatelessWidget {
  const HttpLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.ref.watch(httpLogsProvider);
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar('HTTP Logs'),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.redAccent.withOpacity(0.12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => context.ref.notifier(httpLogsProvider).clear(),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'No HTTP logs yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                ),
              ),
            ),
          ...logs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kGlassFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGlassBorder, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: CopyableText(
                        prefix: TextSpan(
                          text: '[${_dateFormat.format(log.timestamp)}] ',
                          style: const TextStyle(
                            color: kAccentCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        name: log.log,
                        value: log.log,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
