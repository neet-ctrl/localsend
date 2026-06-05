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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: basicLocalSendAppbar('HTTP Logs'),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        children: [
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? kGlassFill : const Color(0xFFF0F4FF),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0D1220),
                ),
                onPressed: () => context.ref.notifier(httpLogsProvider).clear(),
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
