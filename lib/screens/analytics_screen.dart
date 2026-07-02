import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _storage = StorageService();
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  static final _cjk = RegExp(r'[\u4e00-\u9fff]');
  static const _stopwords = {
    'the', 'a', 'an', 'and', 'is', 'i', 'to', 'of', 'in', 'it', 'my', 'me',
    'was', 'that', 'this', 'for', 'on', 'with', 'so', 'but', 'im', 'am',
    '的', '了', '我', '是', '在', '就', '和', '也', '都', '有', '不',
  };

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

  List<MapEntry<DateTime, int>> _last7Days() {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final days = <DateTime, int>{
      for (int i = 6; i >= 0; i--) base.subtract(Duration(days: i)): 0,
    };
    for (final e in _entries) {
      final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      if (days.containsKey(day)) days[day] = days[day]! + 1;
    }
    return days.entries.toList();
  }

  Map<String, int> _languageCounts() {
    final counts = {'中文': 0, 'English': 0};
    for (final e in _entries) {
      if (_cjk.hasMatch(e.transcript)) {
        counts['中文'] = counts['中文']! + 1;
      } else {
        counts['English'] = counts['English']! + 1;
      }
    }
    return counts;
  }

  int _currentStreak() {
    if (_entries.isEmpty) return 0;
    final days = _entries
        .map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

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
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).toList();
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    'No data yet — speak a few poems first',
                    style: TextStyle(color: AppColors.paper.withOpacity(0.5)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 28),
                    _sectionLabel('Persona distribution'),
                    const SizedBox(height: 16),
                    _buildPersonaPie(),
                    const SizedBox(height: 28),
                    _sectionLabel('Last 7 days'),
                    const SizedBox(height: 16),
                    _buildWeekBarChart(),
                    const SizedBox(height: 28),
                    _sectionLabel('Language'),
                    const SizedBox(height: 12),
                    _buildLanguageRow(),
                    const SizedBox(height: 28),
                    _sectionLabel('Frequent words in what you said'),
                    const SizedBox(height: 12),
                    _buildKeywordChips(),
                    const SizedBox(height: 20),
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
      );

  Widget _buildStatsRow() {
    final streak = _currentStreak();
    final personaCounts = _personaCounts();
    final topPersona = personaCounts.entries.isEmpty
        ? '—'
        : (personaCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Poems', value: '${_entries.length}', color: AppColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Streak', value: '$streak d', color: AppColors.seal)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Top school', value: topPersona, color: AppColors.jade, small: true)),
      ],
    );
  }

  Widget _buildPersonaPie() {
    final counts = _personaCounts();
    final entries = counts.entries.toList();
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: entries.asMap().entries.map((e) {
                final index = e.key;
                final data = e.value;
                final color = AppColors.chartPalette[index % AppColors.chartPalette.length];
                final pct = total == 0 ? 0 : (data.value / total * 100);
                return PieChartSectionData(
                  value: data.value.toDouble(),
                  color: color,
                  radius: 46,
                  title: '${pct.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: entries.asMap().entries.map((e) {
              final index = e.key;
              final data = e.value;
              final color = AppColors.chartPalette[index % AppColors.chartPalette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 6),
                  Text('${data.key} (${data.value})', style: TextStyle(color: AppColors.paper.withOpacity(0.75), fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekBarChart() {
    final days = _last7Days();
    final maxVal = days.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal + 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _weekdayLabel(days[index].key.weekday),
                      style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: days.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value.toDouble(),
                  color: AppColors.gold,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLanguageRow() {
    final counts = _languageCounts();
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Row(
      children: counts.entries.map((e) {
        final pct = total == 0 ? 0 : (e.value / total * 100).round();
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppColors.inkSurface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text('$pct%', style: const TextStyle(color: AppColors.paper, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.key, style: TextStyle(color: AppColors.paper.withOpacity(0.55), fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeywordChips() {
    final keywords = _topKeywords();
    if (keywords.isEmpty) {
      return Text('Not enough data yet', style: TextStyle(color: AppColors.paper.withOpacity(0.4)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keywords
          .map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.inkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inkBorder),
                ),
                child: Text('${k.key} · ${k.value}', style: const TextStyle(color: AppColors.paper, fontSize: 13)),
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool small;

  const _StatCard({required this.label, required this.value, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: small ? 15 : 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 11)),
        ],
      ),
    );
  }
}