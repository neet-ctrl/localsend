import 'dart:io';

import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/hub/hub_remote_file.dart';
import 'package:localsend_app/provider/hub/hub_files_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class HubRemoteFilesPage extends StatelessWidget {
  final Device device;

  const HubRemoteFilesPage({required this.device, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch(hubFilesProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1220) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccentCyan),
          onPressed: () {
            if (state.pathStack.isNotEmpty) {
              context.notifier(hubFilesProvider).goBack();
            } else {
              context.notifier(hubFilesProvider).reset();
              context.pop();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.alias, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            Text(
              state.currentPath,
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: kAccentCyan), onPressed: () => context.notifier(hubFilesProvider).refresh()),
        ],
      ),
      body: Column(
        children: [
          _buildBreadcrumb(context, state, isDark),
          if (state.transfers.isNotEmpty) _buildTransferQueue(context, state, isDark),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
                : state.error != null
                ? _buildError(context, state.error!, isDark)
                : state.files.isEmpty
                ? _buildEmpty(isDark)
                : _buildFileList(context, state, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context, HubFilesState state, bool isDark) {
    final parts = state.currentPath.split(Platform.pathSeparator).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      color: isDark ? const Color(0xFF0D1220) : Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          GestureDetector(
            onTap: () => context.notifier(hubFilesProvider).navigate('/'),
            child: const Center(child: Icon(Icons.home_rounded, color: kAccentCyan, size: 18)),
          ),
          ...parts.map((part) => Row(
            children: [
              Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5)),
              Text(part, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7FA3))),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildTransferQueue(BuildContext context, HubFilesState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 8),
          ...state.transfers.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(t.done ? Icons.check_circle_rounded : (t.failed ? Icons.error_rounded : Icons.downloading_rounded),
                    color: t.done ? const Color(0xFF00C853) : (t.failed ? Colors.red : kAccentCyan), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.fileName, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (!t.done && !t.failed)
                        LinearProgressIndicator(value: t.progress, backgroundColor: kAccentCyan.withValues(alpha: 0.1), valueColor: const AlwaysStoppedAnimation(kAccentCyan)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => context.notifier(hubFilesProvider).removeTransfer(t.id),
                  color: isDark ? const Color(0xFF6B7FA3) : Colors.grey,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text('Connection Error', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text(error, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.notifier(hubFilesProvider).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: kAccentCyan, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: kAccentPurple.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Empty Folder', style: TextStyle(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, HubFilesState state, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: state.files.length,
      itemBuilder: (ctx, i) {
        final file = state.files[i];
        final isSelected = state.selectedFiles.contains(file.path);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              if (file.isDirectory) {
                context.notifier(hubFilesProvider).navigate(file.path);
              } else if (state.selectedFiles.isNotEmpty) {
                context.notifier(hubFilesProvider).toggleSelection(file.path);
              }
            },
            onLongPress: () => context.notifier(hubFilesProvider).toggleSelection(file.path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: isSelected
                      ? [kAccentCyan.withValues(alpha: 0.15), kAccentCyan.withValues(alpha: 0.08)]
                      : (isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isSelected ? kAccentCyan.withValues(alpha: 0.5) : (isDark ? kGlassBorder : const Color(0x1A000000)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: file.isDirectory
                          ? kAccentPurple.withValues(alpha: 0.15)
                          : _fileColor(file.name).withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      file.isDirectory ? Icons.folder_rounded : _fileIcon(file.name),
                      color: file.isDirectory ? kAccentPurple : _fileColor(file.name),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (!file.isDirectory)
                          Text(file.displaySize, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4))),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, color: kAccentCyan, size: 20)
                  else if (!file.isDirectory)
                    GestureDetector(
                      onTap: () => _downloadFile(context, file, isDark),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: kAccentCyan.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.download_rounded, color: kAccentCyan, size: 18),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: kAccentPurple, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadFile(BuildContext context, HubRemoteFile file, bool isDark) async {
    try {
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}/${file.name}';
      context.notifier(hubFilesProvider).downloadFile(file, savePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${file.name}...'),
            backgroundColor: const Color(0xFF1A2235),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red.shade900),
        );
      }
    }
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'bmp':
        return Icons.image_rounded;
      case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm':
        return Icons.videocam_rounded;
      case 'mp3': case 'wav': case 'aac': case 'flac': case 'ogg':
        return Icons.music_note_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx':
        return Icons.description_rounded;
      case 'xls': case 'xlsx':
        return Icons.table_chart_rounded;
      case 'zip': case 'rar': case '7z': case 'tar': case 'gz':
        return Icons.folder_zip_rounded;
      case 'apk':
        return Icons.android_rounded;
      case 'txt': case 'md': case 'json': case 'xml': case 'csv':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return const Color(0xFF00BFA5);
      case 'mp4': case 'mkv': case 'avi': case 'mov':
        return const Color(0xFF2979FF);
      case 'mp3': case 'wav': case 'aac': case 'flac':
        return const Color(0xFFFF6D00);
      case 'pdf':
        return Colors.red;
      case 'zip': case 'rar': case '7z':
        return const Color(0xFFFFAB00);
      case 'apk':
        return const Color(0xFF00C853);
      default:
        return const Color(0xFF8899BB);
    }
  }
}
