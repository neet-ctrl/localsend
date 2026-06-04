import 'dart:io';
import 'dart:ui';

import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/dialogs/file_info_dialog.dart';
import 'package:localsend_app/widget/dialogs/history_clear_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _EntryOption {
  open,
  showInFolder,
  info,
  delete;

  String get label => switch (this) {
    _EntryOption.open => t.receiveHistoryPage.entryActions.open,
    _EntryOption.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
    _EntryOption.info => t.receiveHistoryPage.entryActions.info,
    _EntryOption.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
  };
}

const _optionsAll = _EntryOption.values;
final _optionsWithoutOpen = [_EntryOption.info, _EntryOption.delete];

class ReceiveHistoryPage extends StatelessWidget {
  const ReceiveHistoryPage({super.key});

  Future<void> _openFile(
    BuildContext context,
    ReceiveHistoryEntry entry,
    Dispatcher<ReceiveHistoryService, List<ReceiveHistoryEntry>> dispatcher,
  ) async {
    if (entry.path != null) {
      await openFile(
        context,
        entry.fileType,
        entry.path!,
        onDeleteTap: () => dispatcher.dispatchAsync(RemoveHistoryEntryAction(entry.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(receiveHistoryProvider);
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: basicLocalSendAppbar(t.receiveHistoryPage.title),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // Action buttons row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  _GlassActionButton(
                    icon: Icons.folder_open,
                    label: t.receiveHistoryPage.openFolder,
                    color: kAccentCyan,
                    enabled: !checkPlatform([TargetPlatform.iOS]),
                    onPressed: () async {
                      final destination =
                          context.read(settingsProvider).destination ?? await getDefaultDestinationDirectory();
                      await openFolder(folderPath: destination);
                    },
                  ),
                  const SizedBox(width: 12),
                  _GlassActionButton(
                    icon: Icons.delete_sweep,
                    label: t.receiveHistoryPage.deleteHistory,
                    color: Colors.redAccent,
                    enabled: entries.isNotEmpty,
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (_) => const HistoryClearDialog(),
                      );
                      if (context.mounted && result == true) {
                        await context.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.12)),
                    const SizedBox(height: 16),
                    Text(
                      t.receiveHistoryPage.empty,
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 18),
                    ),
                  ],
                ),
              ),
            )
          else
            ...entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: GestureDetector(
                  onTap: entry.path != null || entry.isMessage
                      ? () async {
                          if (entry.isMessage) {
                            final vm = ViewProvider((ref) {
                              return ReceivePageVm(
                                status: SessionStatus.waiting,
                                sender: Device(
                                  signalingId: null,
                                  ip: '0.0.0.0',
                                  version: '1.0.0',
                                  port: 8080,
                                  https: false,
                                  fingerprint: 'fingerprint',
                                  alias: entry.senderAlias,
                                  deviceModel: 'deviceModel',
                                  deviceType: DeviceType.web,
                                  download: true,
                                  discoveryMethods: const {},
                                ),
                                showSenderInfo: false,
                                files: [],
                                message: entry.fileName,
                                onAccept: () {},
                                onDecline: () {},
                                onClose: () {},
                              );
                            });
                            // ignore: unawaited_futures
                            context.push(() => ReceivePage(vm));
                            return;
                          }
                          await _openFile(context, entry, context.redux(receiveHistoryProvider));
                        }
                      : null,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FilePathThumbnail(path: entry.path, fileType: entry.fileType),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.fileName,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${entry.timestampString} · ${entry.fileSize.asReadableFileSize} · ${entry.senderAlias}',
                                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<_EntryOption>(
                                color: kSurface,
                                icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.45), size: 20),
                                onSelected: (_EntryOption item) async {
                                  switch (item) {
                                    case _EntryOption.open:
                                      await _openFile(context, entry, context.redux(receiveHistoryProvider));
                                      break;
                                    case _EntryOption.showInFolder:
                                      if (entry.path != null) {
                                        await openFolder(
                                          folderPath: File(entry.path!).parent.path,
                                          fileName: path.basename(entry.path!),
                                        );
                                      }
                                      break;
                                    case _EntryOption.info:
                                      // ignore: use_build_context_synchronously
                                      await showDialog(context: context, builder: (_) => FileInfoDialog(entry: entry));
                                      break;
                                    case _EntryOption.delete:
                                      // ignore: use_build_context_synchronously
                                      await context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntryAction(entry.id));
                                      break;
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return (entry.path != null ? _optionsAll : _optionsWithoutOpen).map((e) {
                                    return PopupMenuItem<_EntryOption>(
                                      value: e,
                                      child: Text(e.label, style: const TextStyle(color: Colors.white)),
                                    );
                                  }).toList();
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
            }),
        ],
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? color.withOpacity(0.35) : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: enabled ? color : Colors.white.withOpacity(0.25),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: enabled ? onPressed : null,
            icon: Icon(icon, size: 18),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
