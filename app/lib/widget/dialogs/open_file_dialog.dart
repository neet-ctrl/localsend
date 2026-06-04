import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:common/model/file_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart' as android_channel;
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:path/path.dart' as path;
import 'package:routerino/routerino.dart';

class OpenFileDialog extends StatefulWidget {
  final String filePath;
  final FileType fileType;
  final bool openGallery;

  const OpenFileDialog({
    super.key,
    required this.filePath,
    required this.fileType,
    required this.openGallery,
  });

  static Future<void> open(
    BuildContext context, {
    required String filePath,
    required FileType fileType,
    required bool openGallery,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => OpenFileDialog(
        filePath: filePath,
        fileType: fileType,
        openGallery: openGallery,
      ),
    );
  }

  @override
  State<OpenFileDialog> createState() => _OpenFileDialogState();
}

class _OpenFileDialogState extends State<OpenFileDialog> {
  late Timer _timer;
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        if (context.mounted) context.pop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
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
                      child: const Icon(Icons.folder_open, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.dialogs.openFile.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  t.dialogs.openFile.content,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                      onPressed: () async {
                        if (widget.openGallery && defaultTargetPlatform == TargetPlatform.android) {
                          await android_channel.openGallery();
                        } else {
                          await openFile(context, widget.fileType, widget.filePath);
                        }
                      },
                      child: Text(t.general.open),
                    ),
                    if (!widget.openGallery)
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: kAccentCyan),
                        onPressed: () async => await openFolder(
                          folderPath: File(widget.filePath).parent.path,
                          fileName: path.basename(widget.filePath),
                        ),
                        child: Text(t.receiveHistoryPage.entryActions.showInFolder),
                      ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.5)),
                      onPressed: () {
                        _timer.cancel();
                        context.pop();
                      },
                      child: Text('${t.general.close} ($_countdown)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
