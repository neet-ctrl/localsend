import 'dart:ui';

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
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.settingsTab.general.language),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          ...[
            null,
            ...AppLocale.values,
          ].map((locale) {
            final isActive = locale == activeLocale;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () async {
                  await context.ref.notifier(settingsProvider).setLocale(locale);
                  if (locale == null) {
                    await LocaleSettings.useDeviceLocale();
                  } else {
                    await LocaleSettings.setLocale(locale);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isActive ? kAccentCyan.withOpacity(0.12) : kGlassFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? kAccentCyan.withOpacity(0.45) : kGlassBorder,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                locale?.humanName ?? t.settingsTab.general.languageOptions.system,
                                style: TextStyle(
                                  color: isActive ? kAccentCyan : Colors.white.withOpacity(0.8),
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccentCyan),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                          ],
                        ),
                      ),
                    ),
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
