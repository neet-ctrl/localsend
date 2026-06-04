import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_type_ext.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/dialogs/file_name_input_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_actions_dialog.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';

class ReceiveOptionsPage extends StatelessWidget {
  final ReceivePageVm vm;

  const ReceiveOptionsPage(this.vm);

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final receiveSession = ref.watch(serverProvider.select((s) => s?.session));
    if (receiveSession == null) {
      return Scaffold(backgroundColor: kBgDark, body: Container());
    }
    final selectState = ref.watch(selectedReceivingFilesProvider);

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.receiveOptionsPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          // Destination card
          _GlassSection(
            title: t.receiveOptionsPage.destination,
            trailing: checkPlatformWithFileSystem()
                ? CustomIconButton(
                    onPressed: () async {
                      final directory = await pickDirectoryPath();
                      if (directory != null) {
                        ref.notifier(serverProvider).setSessionDestinationDir(directory);
                      }
                    },
                    child: const Icon(Icons.edit, color: kAccentCyan),
                  )
                : null,
            child: Text(
              checkPlatformWithFileSystem()
                  ? receiveSession.destinationDirectory
                  : t.receiveOptionsPage.appDirectory,
              style: TextStyle(color: kAccentCyan.withOpacity(0.85), fontSize: 13),
            ),
          ),

          if (checkPlatformWithGallery()) ...[
            const SizedBox(height: 14),
            _GlassSection(
              title: t.receiveOptionsPage.saveToGallery,
              child: Row(
                children: [
                  CustomDropdownButton<bool>(
                    value: receiveSession.saveToGallery,
                    expanded: false,
                    items: [false, true].map((b) {
                      return DropdownMenuItem(
                        value: b,
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 80),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              b ? t.general.on : t.general.off,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (b) => ref.notifier(serverProvider).setSessionSaveToGallery(b),
                  ),
                  if (receiveSession.containsDirectories && !receiveSession.saveToGallery) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.receiveOptionsPage.saveToGalleryOff,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Files header
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
                t.general.files,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: t.dialogs.quickActions.title,
                child: CustomIconButton(
                  onPressed: () async {
                    await showDialog(context: context, builder: (_) => const QuickActionsDialog());
                  },
                  child: const Icon(Icons.tips_and_updates, color: kAccentCyan),
                ),
              ),
              Tooltip(
                message: t.general.reset,
                child: CustomIconButton(
                  onPressed: () => ref.notifier(selectedReceivingFilesProvider).setFiles(vm.files),
                  child: const Icon(Icons.undo, color: kAccentCyan),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...vm.files.map((file) {
            final included = selectState.containsKey(file.id);
            final renamed = included && selectState[file.id] != file.fileName;
            final statusColor = !included
                ? Colors.white.withOpacity(0.3)
                : renamed
                    ? Colors.orangeAccent
                    : Colors.white.withOpacity(0.4);
            final statusText = !included
                ? t.general.skipped
                : (renamed ? t.general.renamed : t.general.unchanged);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(file.fileType.icon, size: 40, color: kAccentCyan.withOpacity(0.75)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectState[file.id] ?? file.fileName,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                                Text(
                                  '$statusText · ${file.size.asReadableFileSize}',
                                  style: TextStyle(color: statusColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomIconButton(
                                onPressed: included
                                    ? () async {
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (_) => FileNameInputDialog(
                                            originalName: file.fileName,
                                            initialName: selectState[file.id]!,
                                          ),
                                        );
                                        if (result != null) {
                                          ref.notifier(selectedReceivingFilesProvider).rename(file.id, result);
                                        }
                                      }
                                    : null,
                                child: Icon(Icons.edit, color: included ? kAccentCyan : Colors.white.withOpacity(0.2), size: 20),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Checkbox(
                                  value: included,
                                  activeColor: kAccentCyan,
                                  checkColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (selected) {
                                    if (selected == true) {
                                      ref.notifier(selectedReceivingFilesProvider).select(file);
                                    } else {
                                      ref.notifier(selectedReceivingFilesProvider).unselect(file.id);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _GlassSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _GlassSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                  ],
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
