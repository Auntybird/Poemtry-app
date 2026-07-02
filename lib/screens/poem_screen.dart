import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PoemScreen extends StatefulWidget {
  final HistoryEntry entry;

  const PoemScreen({super.key, required this.entry});

  @override
  State<PoemScreen> createState() => _PoemScreenState();
}

class _PoemScreenState extends State<PoemScreen> {
  final _storage = StorageService();
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.entry.isFavorite;
  }

  Future<void> _toggleFavorite() async {
    await _storage.toggleFavorite(widget.entry.id);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _copyToClipboard() {
    final text = '${widget.entry.poem}\n\n${widget.entry.explanation}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.inkSurfaceLight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.copy_rounded, color: AppColors.paper.withOpacity(0.7), size: 20),
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? AppColors.seal : AppColors.paper.withOpacity(0.6),
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PersonaTag(name: entry.personaName, english: entry.personaEnglishName),
                  const SizedBox(width: 8),
                  if (entry.type == 'written')
                    Icon(Icons.edit_note_rounded, size: 16, color: AppColors.paper.withOpacity(0.4))
                  else
                    Icon(Icons.mic_rounded, size: 16, color: AppColors.paper.withOpacity(0.4)),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                entry.poem,
                style: const TextStyle(
                  color: AppColors.paper,
                  fontSize: 22,
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              Container(height: 1, color: AppColors.inkBorder),
              const SizedBox(height: 20),
              Text(
                entry.type == 'written' ? 'You wrote' : 'You said',
                style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                entry.transcript,
                style: TextStyle(color: AppColors.paper.withOpacity(0.75), fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
              ),
              const SizedBox(height: 28),
              Text(
                entry.type == 'written' ? 'Guidance' : 'Meaning',
                style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(entry.explanation, style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.6)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaTag extends StatelessWidget {
  final String name;
  final String english;

  const _PersonaTag({required this.name, required this.english});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Text('$name · $english', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}