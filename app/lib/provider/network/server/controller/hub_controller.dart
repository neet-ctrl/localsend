import 'dart:convert';
import 'dart:io';

import 'package:localsend_app/model/hub/hub_message.dart';
import 'package:localsend_app/model/hub/hub_remote_file.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:logging/logging.dart';

final _logger = Logger('HubController');

/// Buffers incoming data from remote devices until the providers consume it.
class HubIncomingBuffer {
  static final HubIncomingBuffer instance = HubIncomingBuffer._();
  HubIncomingBuffer._();

  final _messages = <HubMessage>[];
  final _callOffers = <Map<String, dynamic>>[];
  final _callAnswers = <Map<String, dynamic>>[];
  final _iceCandidates = <Map<String, dynamic>>[];
  bool _callHangupReceived = false;

  void addMessage(HubMessage msg) => _messages.add(msg);

  List<HubMessage> drainMessages() {
    final result = List<HubMessage>.from(_messages);
    _messages.clear();
    return result;
  }

  void addCallOffer(Map<String, dynamic> offer) => _callOffers.add(offer);

  Map<String, dynamic>? drainCallOffer() {
    if (_callOffers.isEmpty) return null;
    return _callOffers.removeAt(0);
  }

  void addCallAnswer(Map<String, dynamic> answer) => _callAnswers.add(answer);

  Map<String, dynamic>? drainCallAnswer() {
    if (_callAnswers.isEmpty) return null;
    return _callAnswers.removeAt(0);
  }

  void addIceCandidate(Map<String, dynamic> candidate) => _iceCandidates.add(candidate);

  List<Map<String, dynamic>> drainIceCandidates() {
    final result = List<Map<String, dynamic>>.from(_iceCandidates);
    _iceCandidates.clear();
    return result;
  }

  void setHangup() => _callHangupReceived = true;

  bool drainHangup() {
    if (_callHangupReceived) {
      _callHangupReceived = false;
      return true;
    }
    return false;
  }
}

class HubController {
  void installRoutes({required SimpleServerRouteBuilder router}) {
    router.post('/hub/message', _handleMessage);
    router.post('/hub/call/offer', _handleCallOffer);
    router.post('/hub/call/answer', _handleCallAnswer);
    router.post('/hub/call/ice', _handleIceCandidates);
    router.post('/hub/call/hangup', _handleHangup);
    router.get('/hub/files', _handleFileList);
    router.get('/hub/file', _handleFileDownload);
    router.get('/hub/info', _handleHubInfo);
  }

  Future<void> _handleMessage(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = HubMessage.fromJson(json);
      HubIncomingBuffer.instance.addMessage(msg);
      _respond(request, 200, {'status': 'ok'});
    } catch (e) {
      _logger.warning('Hub message parse error: $e');
      _respond(request, 400, {'error': e.toString()});
    }
  }

  Future<void> _handleCallOffer(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      // Inject the real IP from the HTTP connection so the receiver can call back
      json['callerIp'] = request.ip;
      HubIncomingBuffer.instance.addCallOffer(json);
      _respond(request, 200, {'status': 'ok'});
    } catch (e) {
      _respond(request, 400, {'error': e.toString()});
    }
  }

  Future<void> _handleCallAnswer(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      HubIncomingBuffer.instance.addCallAnswer(json);
      _respond(request, 200, {'status': 'ok'});
    } catch (e) {
      _respond(request, 400, {'error': e.toString()});
    }
  }

  Future<void> _handleIceCandidates(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      HubIncomingBuffer.instance.addIceCandidate(json);
      _respond(request, 200, {'status': 'ok'});
    } catch (e) {
      _respond(request, 400, {'error': e.toString()});
    }
  }

  Future<void> _handleHangup(HttpRequest request) async {
    HubIncomingBuffer.instance.setHangup();
    _respond(request, 200, {'status': 'ok'});
  }

  Future<void> _handleFileList(HttpRequest request) async {
    try {
      final rawPath = request.uri.queryParameters['path'] ?? '/';
      final dir = Directory(rawPath);
      if (!await dir.exists()) {
        _respond(request, 404, {'error': 'not found'});
        return;
      }
      final entries = await dir.list().toList();
      final files = <HubRemoteFile>[];
      for (final e in entries) {
        try {
          final stat = await e.stat();
          final name = e.path.split(Platform.pathSeparator).last;
          if (name.startsWith('.')) continue;
          files.add(HubRemoteFile(
            name: name,
            path: e.path,
            isDirectory: e is Directory,
            size: e is File ? stat.size : null,
            modified: stat.modified.millisecondsSinceEpoch,
          ));
        } catch (_) {}
      }
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(files.map((f) => f.toJson()).toList()));
      await request.response.close();
    } catch (e) {
      _respond(request, 500, {'error': e.toString()});
    }
  }

  Future<void> _handleFileDownload(HttpRequest request) async {
    try {
      final path = request.uri.queryParameters['path'] ?? '';
      final file = File(path);
      if (!await file.exists()) {
        _respond(request, 404, {'error': 'not found'});
        return;
      }
      final stat = await file.stat();
      request.response.headers.set(HttpHeaders.contentLengthHeader, stat.size);
      request.response.headers.set('content-disposition',
          'attachment; filename="${file.path.split(Platform.pathSeparator).last}"');
      await request.response.addStream(file.openRead());
      await request.response.close();
    } catch (e) {
      _respond(request, 500, {'error': e.toString()});
    }
  }

  Future<void> _handleHubInfo(HttpRequest request) async {
    _respond(request, 200, {
      'hubVersion': '1.0',
      'chat': true,
      'voiceCall': true,
      'videoCall': true,
      'files': true,
    });
  }

  void _respond(HttpRequest request, int status, Map<String, dynamic> body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }
}
