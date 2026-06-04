import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/util/network_interfaces.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:local_hero/local_hero.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/labeled_checkbox.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:moform/moform.dart';
import 'package:refena_flutter/refena_flutter.dart';

class NetworkInterfacesPage extends StatefulWidget {
  const NetworkInterfacesPage();

  @override
  State<NetworkInterfacesPage> createState() => _NetworkInterfacesPageState();
}

class _NetworkInterfacesPageState extends State<NetworkInterfacesPage> {
  List<(String, List<String>)> rawInterfaces = [];

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    getNetworkInterfaces(whitelist: null, blacklist: null).then((value) {
      if (mounted) {
        setState(() {
          rawInterfaces = value.map((e) => (e.name, e.addresses.map((a) => a.address).toList())).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch(settingsProvider);
    final currList = settings.networkWhitelist ?? settings.networkBlacklist ?? [];
    final Future<void> Function(List<String>?) updateFunction = settings.networkWhitelist != null
        ? context.notifier(settingsProvider).setNetworkWhitelist
        : context.notifier(settingsProvider).setNetworkBlacklist;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.networkInterfacesPage.title),
      body: LocalHeroScope(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: ResponsiveListView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          children: [
            // Info card
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGlassBorder, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      t.networkInterfacesPage.info,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.65), height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Preview label
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
                Text(
                  t.networkInterfacesPage.preview,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Interface cards horizontal scroll
            ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.unknown,
                },
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: rawInterfaces.mapIndexed((i, e) {
                    final ignored = isNetworkIgnoredRaw(
                      networkWhitelist: settings.networkWhitelist,
                      networkBlacklist: settings.networkBlacklist,
                      interface: e.$2,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: ignored ? Colors.white.withOpacity(0.04) : kAccentCyan.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ignored ? Colors.white.withOpacity(0.1) : kAccentCyan.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '[#${i + 1}] ${e.$1}',
                                    style: TextStyle(
                                      color: ignored ? Colors.white.withOpacity(0.25) : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      decoration: ignored ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  ...e.$2.map((ip) => Text(
                                    ip,
                                    style: TextStyle(
                                      color: ignored ? Colors.white.withOpacity(0.2) : kAccentCyan,
                                      fontSize: 12,
                                      fontFamily: 'RobotoMono',
                                      decoration: ignored ? TextDecoration.lineThrough : null,
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Whitelist / blacklist toggle
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: kGlassFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGlassBorder, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LabeledCheckbox(
                          label: t.networkInterfacesPage.whitelist,
                          value: settings.networkWhitelist != null,
                          onChanged: (value) async {
                            if (value == false) {
                              await context.notifier(settingsProvider).setNetworkWhitelist(null);
                            } else {
                              await context.notifier(settingsProvider).setNetworkWhitelist(
                                switch (currList) { [] => [''], _ => [...currList] },
                              );
                              if (context.mounted) await context.notifier(settingsProvider).setNetworkBlacklist(null);
                            }
                          },
                        ),
                        LabeledCheckbox(
                          label: t.networkInterfacesPage.blacklist,
                          value: settings.networkBlacklist != null,
                          onChanged: (value) async {
                            if (value == false) {
                              await context.notifier(settingsProvider).setNetworkBlacklist(null);
                            } else {
                              await context.notifier(settingsProvider).setNetworkBlacklist(
                                switch (currList) { [] => [''], _ => [...currList] },
                              );
                              if (context.mounted) await context.notifier(settingsProvider).setNetworkWhitelist(null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // List entries
            ...currList.mapIndexed((i, e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StringField(
                  value: e,
                  onChanged: (value) async {
                    await updateFunction([
                      ...currList.sublist(0, i),
                      value,
                      ...currList.sublist(i + 1),
                    ]);
                  },
                  builder: (context, controller) {
                    return TextFieldTv(
                      name: t.networkInterfacesPage.whitelist,
                      controller: controller,
                      onDelete: () async {
                        if (currList.length == 1) {
                          await updateFunction(null);
                          return;
                        }
                        await updateFunction([
                          ...currList.sublist(0, i),
                          ...currList.sublist(i + 1),
                        ]);
                      },
                    );
                  },
                ),
              );
            }),

            if (settings.networkWhitelist != null || settings.networkBlacklist != null)
              LocalHero(
                tag: 'network_interfaces_bottom',
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.general.example}:',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                        ),
                        Text('123.123.123.123',
                            style: TextStyle(color: kAccentCyan.withOpacity(0.6), fontSize: 12, fontFamily: 'RobotoMono')),
                        Text('123.123.123.*',
                            style: TextStyle(color: kAccentCyan.withOpacity(0.6), fontSize: 12, fontFamily: 'RobotoMono')),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                        boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () async => await updateFunction([...currList, '']),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(t.general.add, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
