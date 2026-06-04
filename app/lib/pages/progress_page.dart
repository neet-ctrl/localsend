import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/file_speed_helper.dart';
import 'package:localsend_app/util/native/open_file.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/taskbar_helper.dart';
import 'package:localsend_app/util/ui/nav_bar_padding.dart';
import 'package:localsend_app/widget/custom_basic_appbar.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_app/widget/dialogs/error_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ProgressPage extends StatefulWidget {
  final bool showAppBar;
  final bool closeSessionOnClose;
  final String sessionId;

  const ProgressPage({
    required this.showAppBar,
    required this.closeSessionOnClose,
    required this.sessionId,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> with Refena {
  int _totalBytes = double.maxFinite.toInt();
  int _lastRemainingTimeUpdate = 0;
  String? _remainingTime;
  List<FileDto> _files = [];
  Set<String> _selectedFiles = {};
  SessionStatus? _lastStatus;
  int _finishCounter = 3;
  Timer? _finishTimer;
  Timer? _wakelockPlusTimer;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        unawaited(WakelockPlus.enable());
      } catch (_) {}

      _wakelockPlusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        final finished =
            ref.read(serverProvider)?.session?.files.values.map((e) => e.status).isFinishedOrSkipped ??
            ref.read(sendProvider)[widget.sessionId]?.files.values.map((e) => e.status).isFinishedOrSkipped ??
            true;
        if (finished) {
          timer.cancel();
          try { unawaited(WakelockPlus.disable()); } catch (_) {}
        } else {
          try { unawaited(WakelockPlus.enable()); } catch (_) {}
        }
      });

      if (ref.read(settingsProvider).autoFinish) {
        _finishTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          final finished =
              ref.read(serverProvider)?.session?.files.values.map((e) => e.status).isFinishedOrSkipped ??
              ref.read(sendProvider)[widget.sessionId]?.files.values.map((e) => e.status).isFinishedOrSkipped ??
              true;
          if (finished) {
            if (_finishCounter == 1) {
              timer.cancel();
              _exit(closeSession: true);
            } else {
              setState(() { _finishCounter--; });
            }
          }
        });
      }

      setState(() {
        final receiveSession = ref.read(serverProvider)?.session;
        if (receiveSession != null) {
          _files = receiveSession.files.values.map((f) => f.file).toList();
          _selectedFiles = receiveSession.files.values
              .where((f) => f.status != FileStatus.skipped)
              .map((f) => f.file.id)
              .toSet();
        } else {
          final sendSession = ref.read(sendProvider)[widget.sessionId];
          if (sendSession != null) {
            _files = sendSession.files.values.map((f) => f.file).toList();
            _selectedFiles = sendSession.files.values
                .where((f) => f.status != FileStatus.skipped)
                .map((f) => f.file.id)
                .toSet();
          }
        }
        _totalBytes = _files.where((f) => _selectedFiles.contains(f.id)).fold(0, (prev, curr) => prev + curr.size);
      });
    });
  }

  void _exit({required bool closeSession}) async {
    final receiveSession = ref.read(serverProvider.select((s) => s?.session));
    final sendSession = ref.read(sendProvider)[widget.sessionId];
    final SessionStatus? status = receiveSession?.status ?? sendSession?.status;
    final keepSession = !closeSession && (status == SessionStatus.sending || status == SessionStatus.finishedWithErrors);
    final result = status == null || keepSession || await _askCancelConfirmation(status);
    if (result && mounted) {
      // ignore: unawaited_futures
      context.popUntilRoot();
    }
  }

  Future<bool> _askCancelConfirmation(SessionStatus status) async {
    final bool result = switch (status == SessionStatus.sending) {
      true => (await context.pushBottomSheet(() => const CancelSessionDialog())) == true,
      false => true,
    };
    if (result) {
      final receiveSession = ref.read(serverProvider)?.session;
      final sendState = ref.read(sendProvider)[widget.sessionId];
      if (receiveSession != null) {
        if (receiveSession.status == SessionStatus.sending) {
          ref.notifier(serverProvider).cancelSession();
        } else {
          ref.notifier(serverProvider).closeSession();
        }
      } else if (sendState != null) {
        if (sendState.status == SessionStatus.sending) {
          ref.notifier(sendProvider).cancelSession(widget.sessionId);
        } else {
          ref.notifier(sendProvider).closeSession(widget.sessionId);
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    super.dispose();
    _finishTimer?.cancel();
    _wakelockPlusTimer?.cancel();
    TaskbarHelper.clearProgressBar(); // ignore: discarded_futures
    try { WakelockPlus.disable(); } catch (_) {} // ignore: discarded_futures
  }

  @override
  Widget build(BuildContext context) {
    final progressNotifier = ref.watch(progressProvider);
    final currBytes = _files.fold<int>(
      0,
      (prev, curr) => prev + ((progressNotifier.getProgress(sessionId: widget.sessionId, fileId: curr.id) * curr.size).round()),
    );

    final receiveSession = ref.watch(serverProvider.select((s) => s?.session));
    final sendSession = ref.watch(sendProvider)[widget.sessionId];
    final SessionState? commonSessionState = receiveSession ?? sendSession;

    if (commonSessionState == null) {
      return Scaffold(backgroundColor: kBgDark, body: Container());
    }

    final status = commonSessionState.status;

    if (status == SessionStatus.sending) {
      // ignore: discarded_futures
      TaskbarHelper.setProgressBar(currBytes, _totalBytes);
    } else if (status != _lastStatus) {
      _lastStatus = status;
      // ignore: discarded_futures
      TaskbarHelper.visualizeStatus(status);
    }

    final title = receiveSession != null ? t.progressPage.titleReceiving : t.progressPage.titleSending;
    final startTime = commonSessionState.startTime;
    final endTime = commonSessionState.endTime;
    final int? speedInBytes;
    if (startTime != null && currBytes >= 500 * 1024) {
      speedInBytes = getFileSpeed(start: startTime, end: endTime ?? DateTime.now().millisecondsSinceEpoch, bytes: currBytes);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRemainingTimeUpdate >= 1000) {
        _remainingTime = getRemainingTime(bytesPerSeconds: speedInBytes, remainingBytes: _totalBytes - currBytes);
        _lastRemainingTimeUpdate = now;
      }
    } else {
      speedInBytes = null;
    }

    final fileStatusMap = receiveSession?.files.map((k, f) => MapEntry(k, f.status)) ?? sendSession!.files.map((k, f) => MapEntry(k, f.status));
    final finishedCount = fileStatusMap.values.where((s) => s == FileStatus.finished).length;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exit(closeSession: widget.closeSessionOnClose);
      },
      canPop: false,
      child: Scaffold(
        backgroundColor: kBgDark,
        appBar: widget.showAppBar ? basicLocalSendAppbar(title) : null,
        body: Stack(
          children: [
            ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 160 + getNavBarPadding(context),
                left: 15,
                right: 15,
              ),
              itemCount: _files.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  if (widget.showAppBar) return Container();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [kAccentCyan, kAccentPurple],
                          ).createShader(bounds),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (checkPlatformWithFileSystem() && receiveSession != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${t.settingsTab.receive.destination}: ',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                                  ),
                                  TextSpan(
                                    text: receiveSession.destinationDirectory,
                                    style: TextStyle(
                                      color: checkPlatform([TargetPlatform.iOS])
                                          ? Colors.white.withOpacity(0.4)
                                          : kAccentCyan,
                                      fontSize: 13,
                                    ),
                                    recognizer: checkPlatform([TargetPlatform.iOS])
                                        ? null
                                        : (TapGestureRecognizer()
                                            ..onTap = () async {
                                              await openFolder(folderPath: receiveSession.destinationDirectory);
                                            }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                if (index == 1) {
                  final errorMessage = sendSession?.errorMessage;
                  if (errorMessage == null) return Container();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SelectableText(
                      errorMessage,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }

                final file = _files[index - 2];
                final String fileName = receiveSession?.files[file.id]?.desiredName ?? file.fileName;
                final fileStatus = fileStatusMap[file.id]!;
                final savedToGallery = receiveSession?.files[file.id]?.savedToGallery ?? false;

                final String? filePath;
                if (receiveSession != null && fileStatus == FileStatus.finished && !savedToGallery) {
                  filePath = receiveSession.files[file.id]!.path;
                } else if (sendSession != null) {
                  filePath = sendSession.files[file.id]!.path;
                } else {
                  filePath = null;
                }

                final String? errorMessage;
                if (receiveSession != null) {
                  errorMessage = receiveSession.files[file.id]!.errorMessage;
                } else if (sendSession != null) {
                  errorMessage = sendSession.files[file.id]!.errorMessage;
                } else {
                  errorMessage = null;
                }

                final Uint8List? thumbnail;
                final AssetEntity? asset;
                if (sendSession != null) {
                  thumbnail = sendSession.files[file.id]!.thumbnail;
                  asset = sendSession.files[file.id]!.asset;
                } else {
                  thumbnail = null;
                  asset = null;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: kAccentCyan.withOpacity(0.05),
                        hoverColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        onTap: filePath != null && receiveSession != null
                            ? () async => openFile(context, file.fileType, filePath!)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kGlassFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kGlassBorder, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SmartFileThumbnail(
                                  bytes: thumbnail,
                                  asset: asset,
                                  path: filePath,
                                  fileType: file.fileType,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.fade,
                                              softWrap: false,
                                            ),
                                          ),
                                          Text(
                                            ' (${file.size.asReadableFileSize})',
                                            style: TextStyle(fontSize: 12, height: 1, color: Colors.white.withOpacity(0.4)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (fileStatus == FileStatus.sending)
                                        CustomProgressBar(
                                          progress: progressNotifier.getProgress(sessionId: widget.sessionId, fileId: file.id),
                                        )
                                      else
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                savedToGallery ? t.progressPage.savedToGallery : fileStatus.label,
                                                style: TextStyle(color: fileStatus.getColor(context), height: 1, fontSize: 12),
                                              ),
                                            ),
                                            if (errorMessage != null) ...[
                                              const SizedBox(width: 5),
                                              InkWell(
                                                onTap: () async {
                                                  await showDialog(
                                                    context: context,
                                                    builder: (_) => ErrorDialog(error: errorMessage!),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                                  child: const Icon(Icons.info, color: Colors.orangeAccent, size: 16),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                if (sendSession != null && fileStatus == FileStatus.failed)
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: kAccentCyan, size: 20),
                                    onPressed: () async {
                                      await ref.notifier(sendProvider).sendFile(
                                        sessionId: widget.sessionId,
                                        isolateIndex: 0,
                                        file: sendSession.files[file.id]!,
                                        isRetry: true,
                                      );
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

            // Bottom glass panel
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kGlassFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGlassBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: kAccentCyan.withOpacity(0.08),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status.getLabel(remainingTime: _remainingTime ?? '-'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: _totalBytes == 0 ? 0 : currBytes / _totalBytes),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                builder: (context, value, child) => CustomProgressBar(progress: value, borderRadius: 6),
                              ),
                              AnimatedCrossFade(
                                crossFadeState: _advanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.topLeft,
                                firstChild: Container(),
                                secondChild: Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.progressPage.total.count(curr: finishedCount, n: _selectedFiles.length),
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      ),
                                      Text(
                                        t.progressPage.total.size(
                                          curr: currBytes.asReadableFileSize,
                                          n: _totalBytes == double.maxFinite.toInt() ? '-' : _totalBytes.asReadableFileSize,
                                        ),
                                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                      ),
                                      if (speedInBytes != null)
                                        Text(
                                          t.progressPage.total.speed(speed: speedInBytes.asReadableFileSize),
                                          style: const TextStyle(color: kAccentCyan, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white.withOpacity(0.55),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () => setState(() => _advanced = !_advanced),
                                    icon: Icon(_advanced ? Icons.keyboard_arrow_up : Icons.info_outline, size: 18),
                                    label: Text(_advanced ? t.general.hide : t.general.advanced, style: const TextStyle(fontSize: 13)),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: status == SessionStatus.sending
                                          ? null
                                          : const LinearGradient(colors: [kAccentCyan, kAccentPurple]),
                                      color: status == SessionStatus.sending ? Colors.redAccent.withOpacity(0.14) : null,
                                      border: status == SessionStatus.sending
                                          ? Border.all(color: Colors.redAccent.withOpacity(0.35), width: 1)
                                          : null,
                                    ),
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _exit(closeSession: true),
                                      icon: Icon(
                                        status == SessionStatus.sending ? Icons.close : Icons.check_circle,
                                        size: 18,
                                      ),
                                      label: Text(
                                        status == SessionStatus.sending
                                            ? t.general.cancel
                                            : _finishTimer != null
                                                ? '${t.general.done} ($_finishCounter)'
                                                : t.general.done,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
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
                ),
              ),
            ),

            checkPlatform([TargetPlatform.macOS])
                ? Positioned(top: 0, left: 0, right: 0, height: 40, child: MoveWindow())
                : const SizedBox(height: 0, width: 0),
          ],
        ),
      ),
    );
  }
}
