import 'dart:convert';
import 'dart:ui';

import 'package:common/model/file_type.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/message_input_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SelectedFilesPage extends StatelessWidget {
  const SelectedFilesPage();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final selectedFiles = ref.watch(selectedSendingFilesProvider);

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.sendTab.selection.title),
      body: ResponsiveListView.single(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        tabletPadding: const EdgeInsets.symmetric(horizontal: 15),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 15)),
            SliverToBoxAdapter(
              child: Row(
                children: [
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.sendTab.selection.files(files: selectedFiles.length),
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                        Text(
                          t.sendTab.selection.size(
                            size: selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize,
                          ),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.redAccent.withOpacity(0.14),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.35), width: 1),
                    ),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
                        context.popUntilRoot();
                      },
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: Text(t.selectedFilesPage.deleteAll),
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                childCount: selectedFiles.length,
                (context, index) {
                  final file = selectedFiles[index];
                  final String? message;
                  if (file.fileType == FileType.text && file.bytes != null) {
                    message = utf8.decode(file.bytes!);
                  } else {
                    message = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: file.path != null ? () async => openFile(context, file.fileType, file.path!) : null,
                      child: ClipRRect(
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
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SmartFileThumbnail.fromCrossFile(file),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message != null
                                              ? '"${message.replaceAll('\n', ' ')}"'
                                              : file.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          file.size.asReadableFileSize,
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (file.fileType == FileType.text && file.bytes != null)
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: kAccentCyan, size: 20),
                                      onPressed: () async {
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (_) => MessageInputDialog(initialText: message),
                                        );
                                        if (result != null) {
                                          ref.redux(selectedSendingFilesProvider).dispatch(
                                            UpdateMessageAction(message: result, index: index),
                                          );
                                        }
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7), size: 20),
                                    onPressed: () {
                                      final currCount = ref.read(selectedSendingFilesProvider).length;
                                      ref.redux(selectedSendingFilesProvider).dispatch(RemoveSelectedFileAction(index));
                                      if (currCount == 1) context.popUntilRoot();
                                    },
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
            SliverToBoxAdapter(child: SizedBox(height: 15 + getNavBarPadding(context))),
          ],
        ),
      ),
    );
  }
}
