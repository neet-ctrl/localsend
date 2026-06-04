import 'dart:ui';

import 'package:common/model/file_type.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/apk_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/sliver/sliver_pinned_header.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ApkPickerPage extends StatefulWidget {
  const ApkPickerPage({super.key});

  @override
  State<ApkPickerPage> createState() => _ApkPickerPageState();
}

class _ApkPickerPageState extends State<ApkPickerPage> with Refena {
  final _textController = TextEditingController();
  final List<Application> _selectedApps = [];

  Future<void> _pickApp(Application app) async {
    await ref.redux(selectedSendingFilesProvider).dispatchAsync(
      AddFilesAction(files: [app], converter: CrossFileConverters.convertApplication),
    );
    if (mounted) context.pop();
  }

  Future<void> _pickApps(List<Application> apps) async {
    for (final app in apps) {
      await ref.redux(selectedSendingFilesProvider).dispatchAsync(
        AddFilesAction(files: [app], converter: CrossFileConverters.convertApplication),
      );
    }
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _textController.dispose();
    ref.dispose(apkSearchParamProvider);
    super.dispose();
  }

  void _appSelection(Application app) {
    setState(() {
      if (_selectedApps.contains(app)) {
        _selectedApps.remove(app);
      } else {
        _selectedApps.add(app);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apkParams = ref.watch(apkSearchParamProvider);
    final apkAsync = ref.watch(apkProvider);

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.apkPickerPage.title),
      floatingActionButton: _selectedApps.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                boxShadow: [BoxShadow(color: kAccentCyan.withOpacity(0.35), blurRadius: 20)],
              ),
              child: FloatingActionButton.extended(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () async => await _pickApps(_selectedApps),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Add ${_selectedApps.length} ${_selectedApps.length == 1 ? "App" : "Apps"}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
      body: ResponsiveListView.single(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        tabletPadding: const EdgeInsets.symmetric(horizontal: 15),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Search bar
            SliverPinnedHeader(
              height: 80,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: TextFormField(
                      controller: _textController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: kAccentCyan,
                      onChanged: (s) {
                        ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: s));
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        fillColor: kGlassFill,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kGlassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kAccentCyan.withOpacity(0.5), width: 1.5),
                        ),
                        prefixIcon: const Icon(Icons.search, color: kAccentCyan),
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        suffixIcon: apkParams.query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  ref.notifier(apkSearchParamProvider).setState((old) => old.copyWith(query: ''));
                                  _textController.clear();
                                },
                                icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.5)),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      t.apkPickerPage.apps(n: apkAsync.data?.length ?? 0),
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text('Select Multiple', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
                        const SizedBox(width: 8),
                        Switch(
                          value: apkParams.selectMultipleApps,
                          onChanged: (bool newValue) {
                            setState(() {
                              apkParams.selectMultipleApps = !apkParams.selectMultipleApps;
                            });
                          },
                          activeTrackColor: kAccentCyan.withOpacity(0.4),
                          activeColor: kAccentCyan,
                          inactiveThumbColor: Colors.white.withOpacity(0.4),
                          inactiveTrackColor: Colors.white.withOpacity(0.08),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // App list
            apkAsync.when(
              data: (appList) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  childCount: appList.length,
                  (context, index) {
                    final app = appList[index];
                    final thumbnail = (app as ApplicationWithIcon).icon;
                    final isSelected = _selectedApps.contains(app);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: InkWell(
                            onTap: () async =>
                                apkParams.selectMultipleApps ? _appSelection(app) : _pickApp(app),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: kAccentCyan.withOpacity(0.1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? kAccentCyan.withOpacity(0.1) : kGlassFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? kAccentCyan.withOpacity(0.4) : kGlassBorder,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    MemoryThumbnail(bytes: thumbnail, size: 52, fileType: FileType.apk),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app.appName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                          ),
                                          Consumer(
                                            builder: (context, ref) {
                                              final appSize = ref.watch(apkSizeProvider(app.apkFilePath));
                                              final appSizeString = appSize.maybeWhen(
                                                data: (size) => '${size.asReadableFileSize} · ',
                                                orElse: () => '',
                                              );
                                              return Text(
                                                '$appSizeString${app.versionName != null ? 'v${app.versionName}' : ''}',
                                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                              );
                                            },
                                          ),
                                          Text(
                                            app.packageName,
                                            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (apkParams.selectMultipleApps)
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isSelected ? kAccentCyan : Colors.white.withOpacity(0.3),
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              error: (e, st) => SliverToBoxAdapter(
                child: Text('Error: $e\n$st', style: const TextStyle(color: Colors.redAccent)),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(kAccentCyan),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(height: getNavBarPadding(context) + 70),
            ),
          ],
        ),
      ),
    );
  }
}
