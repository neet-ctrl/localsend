import 'dart:async';

enum HubLogLevel { info, warn, error }

enum HubLogCategory { network, calls, messages, files, discovery }

class HubLogEntry {
  final DateTime time;
  final HubLogLevel level;
  final HubLogCategory category;
  final String message;

  HubLogEntry({
    required this.time,
    required this.level,
    required this.category,
    required this.message,
  });

  String get levelTag => switch (level) {
        HubLogLevel.info => 'INFO',
        HubLogLevel.warn => 'WARN',
        HubLogLevel.error => 'ERR ',
      };

  String get categoryTag => switch (category) {
        HubLogCategory.network => 'NET  ',
        HubLogCategory.calls => 'CALL ',
        HubLogCategory.messages => 'MSG  ',
        HubLogCategory.files => 'FILES',
        HubLogCategory.discovery => 'DISC ',
      };

  String get timeTag {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() => '[$timeTag][$levelTag][$categoryTag] $message';
}

class HubLogger {
  static final HubLogger instance = HubLogger._();
  HubLogger._();

  static const _maxEntries = 500;
  final _entries = <HubLogEntry>[];
  final _controller = StreamController<HubLogEntry>.broadcast();

  Stream<HubLogEntry> get stream => _controller.stream;

  List<HubLogEntry> get entries => List.unmodifiable(_entries);

  void _add(HubLogLevel level, HubLogCategory cat, String msg) {
    final entry = HubLogEntry(
      time: DateTime.now(),
      level: level,
      category: cat,
      message: msg,
    );
    _entries.add(entry);
    if (_entries.length > _maxEntries) _entries.removeAt(0);
    if (!_controller.isClosed) _controller.add(entry);
  }

  void info(HubLogCategory cat, String msg) => _add(HubLogLevel.info, cat, msg);
  void warn(HubLogCategory cat, String msg) => _add(HubLogLevel.warn, cat, msg);
  void error(HubLogCategory cat, String msg) => _add(HubLogLevel.error, cat, msg);

  String export({HubLogCategory? filter}) {
    final src = filter == null ? _entries : _entries.where((e) => e.category == filter);
    return src.map((e) => e.toString()).join('\n');
  }

  void clear() => _entries.clear();
}
