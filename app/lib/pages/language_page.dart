import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  void initState() {
    super.initState();

    // ignore: discarded_futures
    LocaleSettings.instance.loadAllLocales().then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final activeLocale = context.ref.watch(settingsProvider.select((s) => s.locale));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: basicLocalSendAppbar(t.sendTab.selection.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          ...[
            null,
            ...AppLocale.values,
          ].map((locale) {
            final isActive = locale == activeLocale;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive
                      ? kAccentCyan.withValues(alpha: 0.08)
                      : (isDark ? kGlassFill : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? kAccentCyan.withValues(alpha: 0.3)
                        : (isDark ? kGlassBorder : const Color(0x1A000000)),
                  ),
                ),
                child: ListTile(
                  onTap: () async {
                    await context.ref.notifier(settingsProvider).setLocale(locale);
                    if (locale == null) {
                      await LocaleSettings.useDeviceLocale();
                    } else {
                      await LocaleSettings.setLocale(locale);
                    }
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(locale?.humanName ?? t.settingsTab.general.languageOptions.system),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.check_circle, color: kAccentCyan),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

extension AppLocaleExt on AppLocale {
  String get humanName {
    return LocaleSettings.instance.translationMap[this]?.locale ?? 'Loading';
  }
}
