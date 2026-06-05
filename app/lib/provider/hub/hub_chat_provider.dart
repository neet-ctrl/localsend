import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:localsend_app/model/hub/hub_message.dart';
import 'package:localsend_app/provider/network/server/controller/hub_controller.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/security_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/hub_http.dart';
import 'package:localsend_app/util/hub_logger.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final _log = HubLogger.instance;
const _uuid = Uuid();
const _prefsKeyPrefix = 'hub_chat_';

class HubChatState {
  final Map<String, List<HubMessage>> conversations;
  final Map<String, bool> typingIndicators;
  final Set<String> onlinePeers;

  const HubChatState({
    this.conversations = const {},
    this.typingIndicators = const {},
    this.onlinePeers = const {},
  });

  HubChatState copyWith({
    Map<String, List<HubMessage>>? conversations,
    Map<String, bool>? typingIndicators,
    Set<String>? onlinePeers,
  }) =>
      HubChatState(
        conversations: conversations ?? this.conversations,
        typingIndicators: typingIndicators ?? this.typingIndicators,
        onlinePeers: onlinePeers ?? this.onlinePeers,
      );

  List<HubMessage> messagesFor(String fingerprint) => conversations[fingerprint] ?? [];

  int unreadCount(String fingerprint) =>
      messagesFor(fingerprint).where((m) => !m.read && m.senderFingerprint == fingerprint).length;
}

final hubChatProvider = NotifierProvider<HubChatNotifier, HubChatState>(
  (ref) => HubChatNotifier(),
);

class HubChatNotifier extends Notifier<HubChatState> {
  Timer? _pollTimer;
  SharedPreferences? _prefs;

  @override
  HubChatState init() {
    _loadFromPrefs();
    _startPolling();
    return const HubChatState();
  }

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefsKeyPrefix)).toList();
    final convos = <String, List<HubMessage>>{};
    for (final key in keys) {
      final fp = key.substring(_prefsKeyPrefix.length);
      final raw = _prefs!.getString(key) ?? '[]';
      try {
        final list =
            (jsonDecode(raw) as List).map((e) => HubMessage.fromJson(e as Map<String, dynamic>)).toList();
        convos[fp] = list;
      } catch (e) {
        _log.warn(HubLogCategory.messages, 'Failed to parse persisted conversation $fp: $e');
      }
    }
    state = state.copyWith(conversations: convos);
    _log.info(HubLogCategory.messages, 'Loaded ${convos.length} conversations from storage');
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final incoming = HubIncomingBuffer.instance.drainMessages();
      if (incoming.isEmpty) return;
      _log.info(HubLogCategory.messages, 'Received ${incoming.length} incoming message(s)');
      final convos = Map<String, List<HubMessage>>.from(state.conversations);
      for (final msg in incoming) {
        final fp = msg.senderFingerprint;
        final list = List<HubMessage>.from(convos[fp] ?? []);
        if (!list.any((m) => m.id == msg.id)) {
          list.add(msg);
          convos[fp] = list;
          _persistConversation(fp, list);
          _log.info(HubLogCategory.messages, 'New message from ${msg.senderAlias} (fp: ${fp.substring(0, 8)}…): "${msg.content}"');
        }
      }
      state = state.copyWith(conversations: convos);
    });
  }

  Future<void> sendMessage({
    required Device device,
    required String content,
    HubMessageType type = HubMessageType.text,
    String? fileName,
    int? fileSize,
  }) async {
    final myFingerprint = ref.read(securityProvider).certificateHash;
    final myAlias = ref.read(settingsProvider).alias;
    final myPort = ref.read(serverProvider)?.port ?? 53317;
    final msg = HubMessage(
      id: _uuid.v4(),
      senderFingerprint: myFingerprint,
      senderAlias: myAlias,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      // Include our own port so receiver knows where to fetch files from
      senderPort: myPort,
      senderHttps: device.https,
    );

    final ip = device.ip;
    final scheme = device.https ? 'https' : 'http';
    final url = '$scheme://$ip:${device.port}/hub/message';
    _log.info(HubLogCategory.messages, 'Sending message to ${device.alias} ($url): "$content"');

    if (ip != null) {
      try {
        final client = lanHttpClient();
        final request = await client.postUrl(Uri.parse(url));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(msg.toJson()));
        final response = await request.close();
        await response.drain<void>();
        msg.delivered = response.statusCode == 200;
        client.close();
        _log.info(HubLogCategory.messages,
            'Send result: status=${response.statusCode} delivered=${msg.delivered}');
      } catch (e) {
        msg.delivered = false;
        _log.error(HubLogCategory.messages, 'Send failed to ${device.alias}: $e');
      }
    } else {
      _log.warn(HubLogCategory.messages, 'Cannot send: device.ip is null for ${device.alias}');
    }

    final fp = device.fingerprint;
    final convos = Map<String, List<HubMessage>>.from(state.conversations);
    final list = List<HubMessage>.from(convos[fp] ?? []);
    list.add(msg);
    convos[fp] = list;
    state = state.copyWith(conversations: convos);
    _persistConversation(fp, list);
  }

  void markRead(String fingerprint) {
    final convos = Map<String, List<HubMessage>>.from(state.conversations);
    final list = (convos[fingerprint] ?? []).map((m) {
      if (!m.read && m.senderFingerprint == fingerprint) {
        m.read = true;
      }
      return m;
    }).toList();
    convos[fingerprint] = list;
    state = state.copyWith(conversations: convos);
    _persistConversation(fingerprint, list);
  }

  void deleteMessage(String fingerprint, String messageId) {
    final convos = Map<String, List<HubMessage>>.from(state.conversations);
    final list = List<HubMessage>.from(convos[fingerprint] ?? [])..removeWhere((m) => m.id == messageId);
    convos[fingerprint] = list;
    state = state.copyWith(conversations: convos);
    _persistConversation(fingerprint, list);
  }

  void clearConversation(String fingerprint) {
    final convos = Map<String, List<HubMessage>>.from(state.conversations);
    convos.remove(fingerprint);
    state = state.copyWith(conversations: convos);
    _prefs?.remove('$_prefsKeyPrefix$fingerprint');
    _log.info(HubLogCategory.messages, 'Cleared conversation for fp ${fingerprint.substring(0, 8)}…');
  }

  Future<void> _persistConversation(String fingerprint, List<HubMessage> messages) async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _prefs!.setString('$_prefsKeyPrefix$fingerprint', raw);
  }
}
