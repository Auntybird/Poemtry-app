import 'package:flutter/material.dart';

import '../models/history_entry.dart';
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
  final _searchController = TextEditingController();

  List<HistoryEntry> _allEntries = [];
  bool _loading = true;
  bool _favoritesOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _storage.getHistory();
    setState(() {
      _allEntries = entries;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    await _storage.clearHistory();
    _load();
  }

  List<HistoryEntry> get _filtered {
    return _allEntries.where((e) {
      if (_favoritesOnly && !e.isFavorite) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.poem.toLowerCase().contains(q) ||
          e.transcript.toLowerCase().contains(q) ||
          e.personaName.contains(_query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (_allEntries.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.paper.withOpacity(0.7)),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_allEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(color: AppColors.paper, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inkSurface,
                        hintText: 'Search poems...',
                        hintStyle: TextStyle(color: AppColors.paper.withOpacity(0.3)),
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.paper.withOpacity(0.4)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _favoritesOnly ? AppColors.seal.withOpacity(0.2) : AppColors.inkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _favoritesOnly ? AppColors.seal : AppColors.inkBorder),
                      ),
                      child: Icon(
                        _favoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _favoritesOnly ? AppColors.seal : AppColors.paper.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : entries.isEmpty
                    ? Center(
                        child: Text(
                          _allEntries.isEmpty ? 'No poems yet' : 'No matches',
                          style: TextStyle(color: AppColors.paper.withOpacity(0.5)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return _HistoryTile(
                            entry: e,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => PoemScreen(entry: e)),
                              );
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
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
                Icon(
                  entry.type == 'written' ? Icons.edit_note_rounded : Icons.mic_rounded,
                  size: 14,
                  color: AppColors.paper.withOpacity(0.35),
                ),
                const SizedBox(width: 6),
                Text(entry.personaName, style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (entry.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.favorite_rounded, size: 14, color: AppColors.seal),
                  ),
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