import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'poem_screen.dart';
import 'write_screen.dart'; // 💡 Imported to navigate to editor screen

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

  Future<void> _deleteItem(String id) async {
    await _storage.deleteHistoryEntry(id);
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
    final voiceEntries = _filtered.where((e) => e.type == 'voice').toList();
    final writtenEntries = _filtered.where((e) => e.type == 'written').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        appBar: AppBar(
          title: const Text('History'),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.paper.withOpacity(0.5),
            dividerColor: AppColors.inkBorder,
            tabs: const [
              Tab(text: 'Spoken Poems'),
              Tab(text: 'Notebook'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_allEntries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                          hintText: 'Search history...',
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
                  : TabBarView(
                      children: [
                        _buildList(voiceEntries, emptyMessage: 'No spoken poems yet'),
                        _buildList(writtenEntries, emptyMessage: 'No notebook entries yet'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<HistoryEntry> entries, {required String emptyMessage}) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          _allEntries.isEmpty ? emptyMessage : 'No matches',
          style: TextStyle(color: AppColors.paper.withOpacity(0.5)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final e = entries[index];
        return Dismissible(
          key: Key(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.8), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (direction) {
            _deleteItem(e.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item deleted'), duration: Duration(seconds: 2)),
            );
          },
          child: _HistoryTile(
            entry: e,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoemScreen(entry: e)));
              _load();
            },
            onEditTap: () async {
              // 💡 Direct route to edit this exact complete poem entry instantly
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WriteScreen(existingEntry: e)),
              );
              _load();
            },
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEditTap; // 💡 Added edit action handler

  const _HistoryTile({required this.entry, required this.onTap, required this.onEditTap});

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    entry.poem,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.gold.withOpacity(0.7)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit entry',
                  onPressed: onEditTap, // 💡 Triggers edit sequence
                ),
              ],
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