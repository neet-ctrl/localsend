import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:routerino/routerino.dart';

class FileInfoDialog extends StatelessWidget {
  final ReceiveHistoryEntry entry;

  const FileInfoDialog({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (!entry.isMessage) ...[
        (t.dialogs.fileInfo.fileName, entry.fileName),
        (t.dialogs.fileInfo.path, entry.savedToGallery ? t.progressPage.savedToGallery : (entry.path ?? '')),
      ],
      (t.dialogs.fileInfo.size, entry.fileSize.asReadableFileSize),
      (t.dialogs.fileInfo.sender, entry.senderAlias),
      (t.dialogs.fileInfo.time, entry.timestampString),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.fileInfo.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...rows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                row.$1,
                                style: const TextStyle(color: kAccentCyan, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SelectableText(
                              row.$2,
                              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                      if (entry.isMessage)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kGlassFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kGlassBorder, width: 1),
                            ),
                            child: SelectableText(
                              entry.fileName,
                              style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                    onPressed: () => context.pop(),
                    child: Text(t.general.close, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
