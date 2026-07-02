import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../models/persona.dart';
import '../services/gemini_text_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _controller = TextEditingController();
  final _service = GeminiTextService();
  final _storage = StorageService();

  Persona _selectedPersona = personas.first;
  bool _loading = false;
  PoemGuidanceResult? _result;
  String? _error;

  Future<void> _askForGuidance() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _service.guide(text, _selectedPersona);

      await _storage.addHistoryEntry(
        HistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          personaName: _selectedPersona.name,
          personaEnglishName: _selectedPersona.englishName,
          transcript: text,
          poem: result.responsePoem,
          explanation: result.guidance,
          type: 'written',
        ),
      );

      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(title: const Text('落笔为诗')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a mentor', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              _PersonaPicker(
                selected: _selectedPersona,
                onChanged: (p) => setState(() => _selectedPersona = p),
              ),
              const SizedBox(height: 24),
              Text('Your writing', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                maxLines: 8,
                style: const TextStyle(color: AppColors.paper, height: 1.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.inkSurface,
                  hintText: 'Write a poem, a reflection, or an idea you hold...',
                  hintStyle: TextStyle(color: AppColors.paper.withOpacity(0.3)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _askForGuidance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ink),
                        )
                      : const Text('Ask for Guidance', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.crimson, fontSize: 13)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 32),
                Container(height: 1, color: AppColors.inkBorder),
                const SizedBox(height: 24),
                Text('Guidance', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 10),
                Text(_result!.guidance, style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.6)),
                const SizedBox(height: 24),
                Text('In response', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.inkSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold.withOpacity(0.25)),
                  ),
                  child: Text(
                    _result!.responsePoem,
                    style: const TextStyle(color: AppColors.paper, fontSize: 17, height: 1.8, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaPicker extends StatelessWidget {
  final Persona selected;
  final ValueChanged<Persona> onChanged;

  const _PersonaPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: personas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = personas[index];
          final isSelected = p.name == selected.name;
          return ChoiceChip(
            label: Text(p.name),
            selected: isSelected,
            onSelected: (_) => onChanged(p),
            backgroundColor: AppColors.inkSurface,
            selectedColor: AppColors.gold.withOpacity(0.25),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.gold : AppColors.paper.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(color: isSelected ? AppColors.gold.withOpacity(0.5) : AppColors.inkBorder),
          );
        },
      ),
    );
  }
}