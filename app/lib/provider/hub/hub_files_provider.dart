import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:localsend_app/model/hub/hub_remote_file.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HubFilesState {
  final Device? remoteDevice;
  final String currentPath;
  final List<String> pathStack;
  final List<HubRemoteFile> files;
  final bool isLoading;
  final String? error;
  final Set<String> selectedFiles;
  final List<HubTransferItem> transfers;

  const HubFilesState({
    this.remoteDevice,
    this.currentPath = '/',
    this.pathStack = const [],
    this.files = const [],
    this.isLoading = false,
    this.error,
    this.selectedFiles = const {},
    this.transfers = const [],
  });

  HubFilesState copyWith({
    Device? remoteDevice,
    String? currentPath,
    List<String>? pathStack,
    List<HubRemoteFile>? files,
    bool? isLoading,
    String? error,
    Set<String>? selectedFiles,
    List<HubTransferItem>? transfers,
    bool clearError = false,
  }) =>
      HubFilesState(
        remoteDevice: remoteDevice ?? this.remoteDevice,
        currentPath: currentPath ?? this.currentPath,
        pathStack: pathStack ?? this.pathStack,
        files: files ?? this.files,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        selectedFiles: selectedFiles ?? this.selectedFiles,
        transfers: transfers ?? this.transfers,
      );
}

class HubTransferItem {
  final String id;
  final String fileName;
  final int? totalBytes;
  int downloadedBytes;
  bool done;
  bool failed;

  HubTransferItem({
    required this.id,
    required this.fileName,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.done = false,
    this.failed = false,
  });

  double get progress => totalBytes == null || totalBytes == 0 ? 0 : downloadedBytes / totalBytes!;
}

final hubFilesProvider = NotifierProvider<HubFilesNotifier, HubFilesState>(
  (ref) => HubFilesNotifier(),
);

class HubFilesNotifier extends Notifier<HubFilesState> {
  @override
  HubFilesState init() => const HubFilesState();

  Future<void> openDevice(Device device) async {
    state = HubFilesState(remoteDevice: device, isLoading: true);
    await _loadPath('/');
  }

  Future<void> navigate(String path) async {
    state = state.copyWith(
      isLoading: true,
      pathStack: [...state.pathStack, state.currentPath],
      clearError: true,
    );
    await _loadPath(path);
  }

  Future<void> goBack() async {
    if (state.pathStack.isEmpty) return;
    final newStack = List<String>.from(state.pathStack);
    final prev = newStack.removeLast();
    state = state.copyWith(isLoading: true, pathStack: newStack);
    await _loadPath(prev);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadPath(state.currentPath);
  }

  Future<void> _loadPath(String path) async {
    final device = state.remoteDevice;
    if (device?.ip == null) {
      state = state.copyWith(isLoading: false, error: 'Device not connected');
      return;
    }

    try {
      final scheme = device!.https ? 'https' : 'http';
      final uri = Uri.parse('$scheme://${device.ip}:${device.port}/hub/files')
          .replace(queryParameters: {'path': path});
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close();

      if (resp.statusCode == 200) {
        final list = (jsonDecode(body) as List)
            .map((e) => HubRemoteFile.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          currentPath: path,
          files: list,
          isLoading: false,
          selectedFiles: {},
          clearError: true,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to load: $body');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Connection error: $e');
    }
  }

  void toggleSelection(String path) {
    final sel = Set<String>.from(state.selectedFiles);
    if (sel.contains(path)) {
      sel.remove(path);
    } else {
      sel.add(path);
    }
    state = state.copyWith(selectedFiles: sel);
  }

  void clearSelection() => state = state.copyWith(selectedFiles: {});

  Future<void> downloadFile(HubRemoteFile file, String savePath) async {
    final device = state.remoteDevice;
    if (device?.ip == null) return;

    final transfer = HubTransferItem(
      id: '${file.path}_${DateTime.now().millisecondsSinceEpoch}',
      fileName: file.name,
      totalBytes: file.size,
    );

    final transfers = List<HubTransferItem>.from(state.transfers)..add(transfer);
    state = state.copyWith(transfers: transfers);

    try {
      final scheme = device!.https ? 'https' : 'http';
      final uri = Uri.parse('$scheme://${device.ip}:${device.port}/hub/file')
          .replace(queryParameters: {'path': file.path});
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();

      final outFile = File(savePath);
      await outFile.parent.create(recursive: true);
      final sink = outFile.openWrite();
      await for (final chunk in resp) {
        sink.add(chunk);
        transfer.downloadedBytes += chunk.length;
        state = state.copyWith(transfers: List.from(state.transfers));
      }
      await sink.close();
      client.close();
      transfer.done = true;
    } catch (e) {
      transfer.failed = true;
    }
    state = state.copyWith(transfers: List.from(state.transfers));
  }

  void removeTransfer(String id) {
    final transfers = state.transfers.where((t) => t.id != id).toList();
    state = state.copyWith(transfers: transfers);
  }

  void reset() => state = const HubFilesState();
}
