import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/hub/hub_message.dart';
import 'package:localsend_app/provider/hub/hub_chat_provider.dart';
import 'package:localsend_app/provider/hub/hub_files_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class HubChatPage extends StatefulWidget {
  final Device device;

  const HubChatPage({required this.device, super.key});

  @override
  State<HubChatPage> createState() => _HubChatPageState();
}

class _HubChatPageState extends State<HubChatPage> with Refena {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _replyToId;
  String? _replyToContent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.notifier(hubChatProvider).markRead(widget.device.fingerprint);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });
    await ref.notifier(hubChatProvider).sendMessage(device: widget.device, content: text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    await ref.notifier(hubChatProvider).sendMessage(
      device: widget.device,
      content: path,
      type: HubMessageType.file,
      fileName: file.name,
      fileSize: file.size,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _downloadFile(HubMessage msg) async {
    final senderIp = msg.senderIp;
    final senderPort = msg.senderPort;
    final fileName = msg.fileName ?? msg.content.split(Platform.pathSeparator).last;

    if (senderIp == null || senderPort == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot download: sender address unknown'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    try {
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';
      ref.notifier(hubFilesProvider).downloadChatFile(
        senderIp: senderIp,
        senderPort: senderPort,
        senderHttps: msg.senderHttps ?? false,
        remotePath: msg.content,
        fileName: fileName,
        savePath: savePath,
        fileSize: msg.fileSize,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Downloading $fileName to Downloads…'),
          backgroundColor: const Color(0xFF1A2235),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red.shade900,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = context.watch(hubChatProvider);
    final messages = chatState.messagesFor(widget.device.fingerprint);
    final myFp = ref.read(securityProvider).certificateHash;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1220) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccentCyan),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)]),
                border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.person_rounded, color: kAccentCyan, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.device.alias, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 3,
                        backgroundColor: widget.device.ip != null ? const Color(0xFF00E676) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.device.ip != null ? 'Online' : 'History',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.device.ip != null ? const Color(0xFF00E676) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: kAccentCyan),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear conversation?'),
                  content: const Text('All messages will be permanently deleted.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) {
                ref.notifier(hubChatProvider).clearConversation(widget.device.fingerprint);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe = msg.senderFingerprint == myFp;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        isDark: isDark,
                        onReply: () => setState(() {
                          _replyToId = msg.id;
                          _replyToContent = msg.content;
                        }),
                        onCopy: () => Clipboard.setData(ClipboardData(text: msg.content)),
                        onDelete: () => ref.notifier(hubChatProvider).deleteMessage(widget.device.fingerprint, msg.id),
                        onDownload: isMe ? null : () => _downloadFile(msg),
                      );
                    },
                  ),
          ),
          if (_replyToContent != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              color: isDark ? const Color(0xFF0D1220) : Colors.white,
              child: Row(
                children: [
                  Container(width: 3, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: kAccentCyan)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _replyToContent!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? const Color(0xFF8899BB) : const Color(0xFF6B7FA3), fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => setState(() { _replyToId = null; _replyToContent = null; }),
                    color: isDark ? const Color(0xFF6B7FA3) : Colors.grey,
                  ),
                ],
              ),
            ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: kAccentCyan.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No messages yet', style: TextStyle(color: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4), fontSize: 15)),
          const SizedBox(height: 8),
          Text('Send a message to start chatting', style: TextStyle(color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1220) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? kGlassBorder : const Color(0x1A000000))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: kAccentCyan),
              onPressed: _sendFile,
              tooltip: 'Send any file',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark ? const Color(0xFF111827) : const Color(0xFFF0F4FF),
                  border: Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Message ${widget.device.alias}...',
                    hintStyle: TextStyle(color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB0BEC5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kAccentCyan, Color(0xFF00B8D9)]),
                  boxShadow: [BoxShadow(color: kAccentCyan.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final HubMessage message;
  final bool isMe;
  final bool isDark;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback? onDownload;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final isFile = message.type == HubMessageType.file;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            gradient: isMe
                ? const LinearGradient(colors: [kAccentCyan, Color(0xFF00B8D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : LinearGradient(
                    colors: isDark ? [const Color(0xFF1A2235), const Color(0xFF111827)] : [Colors.white, const Color(0xFFF0F4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: isMe ? null : Border.all(color: isDark ? kGlassBorder : const Color(0x1A000000)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isFile) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insert_drive_file_rounded, size: 16, color: isMe ? Colors.black : kAccentCyan),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        message.fileName ?? message.content.split(Platform.pathSeparator).last,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.black : (isDark ? Colors.white : Colors.black),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (message.fileSize != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatSize(message.fileSize!),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.black54 : (isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
                    ),
                  ),
                ],
                // Download button for received files
                if (!isMe && onDownload != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDownload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: kAccentCyan.withValues(alpha: 0.15),
                        border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 14, color: kAccentCyan),
                          SizedBox(width: 4),
                          Text('Download', style: TextStyle(color: kAccentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ] else
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.black : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.black54 : (isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4)),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.delivered ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: message.delivered ? Colors.black54 : Colors.black38,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Reply'), onTap: () { Navigator.pop(context); onReply(); }),
            if (!isMe && onDownload != null && message.type == HubMessageType.file)
              ListTile(leading: const Icon(Icons.download_rounded, color: kAccentCyan), title: const Text('Download File'), onTap: () { Navigator.pop(context); onDownload!(); }),
            if (message.type == HubMessageType.text)
              ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy'), onTap: () { Navigator.pop(context); onCopy(); }),
            ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); onDelete(); }),
          ],
        ),
      ),
    );
  }
}
