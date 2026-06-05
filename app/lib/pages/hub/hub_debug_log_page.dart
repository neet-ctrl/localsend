import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/util/hub_logger.dart';

class HubDebugLogPage extends StatefulWidget {
  const HubDebugLogPage({super.key});

  @override
  State<HubDebugLogPage> createState() => _HubDebugLogPageState();
}

class _HubDebugLogPageState extends State<HubDebugLogPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final ScrollController _scroll;
  StreamSubscription<HubLogEntry>? _sub;
  final List<HubLogEntry> _entries = [];
  bool _autoScroll = true;
  HubLogCategory? _activeFilter;

  static const _categories = [
    null, // All
    HubLogCategory.calls,
    HubLogCategory.messages,
    HubLogCategory.files,
    HubLogCategory.network,
    HubLogCategory.discovery,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _scroll = ScrollController();
    _entries.addAll(HubLogger.instance.entries);
    _sub = HubLogger.instance.stream.listen((entry) {
      if (!mounted) return;
      setState(() => _entries.add(entry));
      if (_autoScroll && _scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _activeFilter = _categories[_tabs.index]);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<HubLogEntry> get _filtered =>
      _activeFilter == null ? _entries : _entries.where((e) => e.category == _activeFilter).toList();

  Future<void> _copyAll() async {
    final text = _filtered.map((e) => e.toString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_filtered.length} log lines copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearAll() {
    HubLogger.instance.clear();
    setState(() => _entries.clear());
  }

  Color _levelColor(HubLogLevel level, bool isDark) => switch (level) {
        HubLogLevel.info => isDark ? const Color(0xFF8BC4F9) : const Color(0xFF1565C0),
        HubLogLevel.warn => const Color(0xFFFFB300),
        HubLogLevel.error => const Color(0xFFFF4D6D),
      };

  Color _categoryColor(HubLogCategory cat) => switch (cat) {
        HubLogCategory.calls => kAccentCyan,
        HubLogCategory.messages => kAccentPurple,
        HubLogCategory.files => const Color(0xFF00BFA5),
        HubLogCategory.network => const Color(0xFFFFB300),
        HubLogCategory.discovery => const Color(0xFFFF6D00),
      };

  String _categoryLabel(HubLogCategory? cat) => switch (cat) {
        null => 'All',
        HubLogCategory.calls => 'Calls',
        HubLogCategory.messages => 'Messages',
        HubLogCategory.files => 'Files',
        HubLogCategory.network => 'Network',
        HubLogCategory.discovery => 'Discovery',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Hub Debug Logs'),
        backgroundColor: isDark ? kBgDark : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0D1220),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Auto-scroll toggle
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            icon: Icon(
              Icons.vertical_align_bottom_rounded,
              color: _autoScroll ? kAccentCyan : Colors.grey,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Copy button
          IconButton(
            tooltip: 'Copy all visible logs',
            icon: const Icon(Icons.copy_rounded),
            onPressed: filtered.isEmpty ? null : _copyAll,
          ),
          // Clear button
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _entries.isEmpty ? null : _clearAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: kAccentCyan,
          labelColor: kAccentCyan,
          unselectedLabelColor: isDark ? const Color(0xFF6B7FA3) : const Color(0xFF9AA5B4),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: _categories.map((cat) {
            final count = cat == null
                ? _entries.length
                : _entries.where((e) => e.category == cat).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _categoryColor(cat),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(_categoryLabel(cat)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (cat == null ? kAccentCyan : _categoryColor(cat)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cat == null ? kAccentCyan : _categoryColor(cat),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal_rounded,
                      size: 48, color: isDark ? const Color(0xFF2A3A5C) : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    'No log entries yet',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF4A5568) : const Color(0xFF9AA5B4),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary bar
                Container(
                  color: isDark ? kBgDark2 : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _SummaryBadge(
                        count: filtered.where((e) => e.level == HubLogLevel.error).length,
                        label: 'Errors',
                        color: const Color(0xFFFF4D6D),
                      ),
                      const SizedBox(width: 8),
                      _SummaryBadge(
                        count: filtered.where((e) => e.level == HubLogLevel.warn).length,
                        label: 'Warnings',
                        color: const Color(0xFFFFB300),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} entries',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF4A5568) : const Color(0xFF9AA5B4),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Per-tab copy button
                      GestureDetector(
                        onTap: _copyAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [kAccentCyan, Color(0xFF00B8D9)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.copy_rounded, size: 12, color: kBgDark),
                              SizedBox(width: 4),
                              Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBgDark)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Log list
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return _LogRow(entry: e, isDark: isDark, levelColor: _levelColor(e.level, isDark), categoryColor: _categoryColor(e.category));
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SummaryBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final HubLogEntry entry;
  final bool isDark;
  final Color levelColor;
  final Color categoryColor;

  const _LogRow({
    required this.entry,
    required this.isDark,
    required this.levelColor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = entry.level == HubLogLevel.error
        ? const Color(0xFFFF4D6D).withValues(alpha: isDark ? 0.07 : 0.04)
        : entry.level == HubLogLevel.warn
            ? const Color(0xFFFFB300).withValues(alpha: isDark ? 0.06 : 0.03)
            : Colors.transparent;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Text(
            entry.timeTag,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: isDark ? const Color(0xFF4A5568) : const Color(0xFF9AA5B4),
            ),
          ),
          const SizedBox(width: 6),
          // Level dot
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: levelColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.categoryTag.trim(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: categoryColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: SelectableText(
              entry.message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: isDark ? const Color(0xFFCDD9E5) : const Color(0xFF1A2235),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
