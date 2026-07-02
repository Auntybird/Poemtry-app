import 'dart:async';

import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../models/persona.dart';
import '../models/writing_draft.dart';
import '../services/gemini_text_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'poem_screen.dart';

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
  bool _loadingGuidance = false;
  bool _completing = false;
  bool _restoringDraft = true;
  bool _justSaved = false;
  String? _guidance;
  String? _background;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _restoreDraft() async {
    final draft = await _storage.getDraft();
    if (draft != null) {
      _controller.text = draft.text;
      _selectedPersona = personas.firstWhere(
        (p) => p.name == draft.personaName,
        orElse: () => personas.first,
      );
      _guidance = draft.guidance;
      _background = draft.background;
    }
    setState(() => _restoringDraft = false);
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (_controller.text.trim().isEmpty && _guidance == null) return;
    await _storage.saveDraft(
      WritingDraft(
        personaName: _selectedPersona.name,
        personaEnglishName: _selectedPersona.englishName,
        text: _controller.text,
        guidance: _guidance,
        background: _background,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 1, milliseconds: 200), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _getGuidance() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loadingGuidance = true;
      _error = null;
    });

    try {
      final result = await _service.getGuidance(text, _selectedPersona);
      setState(() {
        _guidance = result.guidance;
        _background = result.background;
      });
      await _persistDraft();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loadingGuidance = false);
    }
  }

  Future<void> _markCompleted() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write something before marking it complete.');
      return;
    }

    setState(() => _completing = true);

    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      personaName: _selectedPersona.name,
      personaEnglishName: _selectedPersona.englishName,
      transcript: text,
      poem: text,
      explanation: _guidance ?? '',
      background: _background ?? '',
      type: 'written',
    );

    await _storage.addHistoryEntry(entry);
    await _storage.clearDraft();

    if (!mounted) return;
    setState(() => _completing = false);

    _controller.removeListener(_onTextChanged);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoemScreen(entry: entry)),
    );

    if (!mounted) return;
    _controller.clear();
    setState(() {
      _guidance = null;
      _background = null;
      _error = null;
    });
    _controller.addListener(_onTextChanged);
  }

  Future<void> _startNewDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inkSurface,
        title: const Text('Start a new draft?',
            style: TextStyle(color: AppColors.paper)),
        content: Text(
          'This clears your current unfinished notebook page. It has not been marked complete.',
          style: TextStyle(color: AppColors.paper.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;

    await _storage.clearDraft();
    _controller.clear();
    setState(() {
      _guidance = null;
      _background = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringDraft) {
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('落笔为诗'),
        actions: [
          AnimatedOpacity(
            opacity: _justSaved ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Draft saved',
                    style: TextStyle(
                        color: AppColors.jade.withOpacity(0.8), fontSize: 12)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.note_add_outlined,
                color: AppColors.paper.withOpacity(0.6)),
            tooltip: 'New draft',
            onPressed: _startNewDraft,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mentor',
                  style: TextStyle(
                      color: AppColors.paper.withOpacity(0.5),
                      fontSize: 13,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              _PersonaPicker(
                selected: _selectedPersona,
                onChanged: (p) {
                  setState(() => _selectedPersona = p);
                  _persistDraft();
                },
              ),
              const SizedBox(height: 24),
              if (_background != null && _background!.isNotEmpty) ...[
                _BackgroundCard(text: _background!),
                const SizedBox(height: 20),
              ],
              Text('Your notebook',
                  style: TextStyle(
                      color: AppColors.paper.withOpacity(0.5),
                      fontSize: 13,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              _NotebookField(controller: _controller),
              const SizedBox(height: 18),
              _ActionButtons(
                loadingGuidance: _loadingGuidance,
                completing: _completing,
                onGetGuidance: _getGuidance,
                onMarkCompleted: _markCompleted,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.crimson, fontSize: 13)),
              ],
              if (_guidance != null && _guidance!.isNotEmpty) ...[
                const SizedBox(height: 28),
                Container(height: 1, color: AppColors.inkBorder),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 16, color: AppColors.violet.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Guidance',
                        style: TextStyle(
                            color: AppColors.paper.withOpacity(0.5),
                            fontSize: 13,
                            letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_guidance!,
                    style: const TextStyle(
                        color: AppColors.paper, fontSize: 15, height: 1.6)),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotebookField extends StatelessWidget {
  final TextEditingController controller;

  const _NotebookField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkBorder),
      ),
      // 🌟 THE FIX: Wrapped the Row in IntrinsicHeight so CrossAxisAlignment.stretch 
      // calculates the visual bounds based on the TextField content instead of infinite screen height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 10,
                maxLines: null,
                style: const TextStyle(
                    color: AppColors.paper, fontSize: 16, height: 1.8),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText:
                      'Begin your poem, reflection, or idea here...\n\nThis page saves itself as you write.',
                  hintStyle: TextStyle(
                      color: AppColors.paper.withOpacity(0.28), height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool loadingGuidance;
  final bool completing;
  final VoidCallback onGetGuidance;
  final VoidCallback onMarkCompleted;

  const _ActionButtons({
    required this.loadingGuidance,
    required this.completing,
    required this.onGetGuidance,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final fontSize = isNarrow ? 13.0 : 14.0;
        final vPad = isNarrow ? 13.0 : 16.0;

        final guidanceButton = OutlinedButton(
          onPressed: loadingGuidance ? null : onGetGuidance,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: BorderSide(color: AppColors.gold.withOpacity(0.5)),
            padding: EdgeInsets.symmetric(vertical: vPad),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loadingGuidance
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.gold),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Get Guidance',
                      style: TextStyle(fontSize: fontSize)),
                ),
        );

        final completeButton = ElevatedButton(
          onPressed: completing ? null : onMarkCompleted,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.seal,
            foregroundColor: AppColors.paper,
            padding: EdgeInsets.symmetric(vertical: vPad),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: completing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.paper),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Mark as Completed',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: fontSize),
                  ),
                ),
        );

        if (isNarrow) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: completeButton),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: guidanceButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: guidanceButton),
            const SizedBox(width: 12),
            Expanded(child: completeButton),
          ],
        );
      },
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  final String text;

  const _BackgroundCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 360;
    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.violet.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.violet.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: isNarrow ? 14 : 16,
                  color: AppColors.violet.withOpacity(0.9)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'References & Background',
                  style: TextStyle(
                    color: AppColors.violet.withOpacity(0.9),
                    fontSize: isNarrow ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
                color: AppColors.paper.withOpacity(0.8),
                fontSize: isNarrow ? 12.5 : 13.5,
                height: 1.55),
          ),
        ],
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
              color: isSelected
                  ? AppColors.gold
                  : AppColors.paper.withOpacity(0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(
                color: isSelected
                    ? AppColors.gold.withOpacity(0.5)
                    : AppColors.inkBorder),
          );
        },
      ),
    );
  }
}