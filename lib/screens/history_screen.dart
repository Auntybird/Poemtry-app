import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../models/poem_result.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'poem_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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

  Future<void> _clearAll() async {
    await _storage.clearHistory();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.paper.withOpacity(0.7)),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _entries.isEmpty
              ? Center(child: Text('No poems yet', style: TextStyle(color: AppColors.paper.withOpacity(0.5))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    return _HistoryTile(
                      entry: e,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PoemScreen(
                              result: PoemResult(
                                personaName: e.personaName,
                                personaEnglishName: e.personaEnglishName,
                                transcript: e.transcript,
                                poem: e.poem,
                                explanation: e.explanation,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.personaName, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(_formatDate(entry.timestamp), style: TextStyle(color: AppColors.paper.withOpacity(0.4), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.poem,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}