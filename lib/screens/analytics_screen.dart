import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _storage = StorageService();
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.getHistory();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Map<String, int> _personaCounts() {
    final counts = <String, int>{};
    for (final e in _entries) {
      counts[e.personaName] = (counts[e.personaName] ?? 0) + 1;
    }
    return counts;
  }

  static const _stopwords = {
    'the', 'a', 'an', 'and', 'is', 'i', 'to', 'of', 'in', 'it', 'my', 'me',
    'was', 'that', 'this', 'for', 'on', 'with', 'so', 'but', 'im', 'am',
    '的', '了', '我', '是', '在', '就', '和', '也', '都', '有', '不',
  };

  List<MapEntry<String, int>> _topKeywords() {
    final counts = <String, int>{};
    for (final e in _entries) {
      final words = e.transcript
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]'), ' ')
          .split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.length < 2 || _stopwords.contains(w)) continue;
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final personaCounts = _personaCounts();
    final maxCount = personaCounts.values.isEmpty
        ? 1
        : personaCounts.values.reduce((a, b) => a > b ? a : b);
    final keywords = _topKeywords();

    return Scaffold(
      backgroundColor: const Color(0xFF14151A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Analytics', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    'No data yet — speak a few poems first',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      '${_entries.length} poems generated',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Persona distribution',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    ...personaCounts.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  e.key,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: e.value / maxCount,
                                    minHeight: 18,
                                    backgroundColor: Colors.white.withOpacity(0.06),
                                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8E7CC3)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${e.value}',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 28),
                    Text(
                      'Frequent words in what you said',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: keywords
                          .map((k) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${k.key} · ${k.value}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}