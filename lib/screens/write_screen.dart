import 'dart:async';

import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../models/persona.dart';
import '../models/writing_draft.dart';
import '../services/gemini_text_service.dart';
import '../services/gemini_service.dart'; 
import '../services/storage_service.dart';
import '../services/audio_mentor_service.dart'; // 🌟 NEW: Imported Audio Service
import '../theme/app_theme.dart';
import '../widgets/poetic_prompt_banner.dart'; 
import 'poem_screen.dart';
import '../services/image_generation_service.dart';

class WriteScreen extends StatefulWidget {
  final WritingDraft? existingDraft;
  final HistoryEntry? existingEntry;

  const WriteScreen({super.key, this.existingDraft, this.existingEntry});

  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _controller = TextEditingController();
  final _service = GeminiTextService();
  final _poemService = GeminiPoemService(); 
  final _storage = StorageService();
  final _audioService = AudioMentorService();
  final _imageService = ImageGenerationService();   // <-- NEW

  String _currentDraftId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isEditingCompletedEntry = false;

  Persona _selectedPersona = personas.first;
  
  bool _loadingGuidance = false;
  bool _analyzingStructure = false; 
  bool _completing = false;
  bool _restoringDraft = true;
  bool _justSaved = false;
  
  String _currentPrompt = "Listening to the universe...";
  bool _isPromptLoading = false;

  String? _guidance;
  String? _background;
  PoemAnalysis? _structuralAnalysis; 
  String? _error;
  Timer? _debounce;
  bool _isPlayingGuidance = false; // 🌟 NEW: Track audio state

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _controller.addListener(_onTextChanged);

    // 🌟 NEW: Listen for audio state changes to update the UI play/stop icons
    _audioService.onStateChanged = (isPlaying) {
      if (mounted) {
        setState(() => _isPlayingGuidance = isPlaying);
      }
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _persistDraft(); // flush any unsaved edit so leaving the screen always saves
    _controller.dispose();
    _audioService.stop(); // 🌟 NEW: Stop talking if the user leaves the screen!
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    if (widget.existingEntry != null) {
      _isEditingCompletedEntry = true;
      _currentDraftId = widget.existingEntry!.id;
      _controller.text = widget.existingEntry!.poem;
      _selectedPersona = personas.firstWhere(
        (p) => p.name == widget.existingEntry!.personaName,
        orElse: () => personas.first,
      );
      _guidance = widget.existingEntry!.explanation;
      _background = widget.existingEntry!.background;
    } else if (widget.existingDraft != null) {
      _isEditingCompletedEntry = false;
      _currentDraftId = widget.existingDraft!.id;
      _controller.text = widget.existingDraft!.text;
      _selectedPersona = personas.firstWhere(
        (p) => p.name == widget.existingDraft!.personaName,
        orElse: () => personas.first,
      );
      _guidance = widget.existingDraft!.guidance;
      _background = widget.existingDraft!.background;
    } else {
      _isEditingCompletedEntry = false;
      final drafts = await _storage.getDrafts();
      if (drafts.isNotEmpty) {
        final draft = drafts.first;
        _currentDraftId = draft.id;
        _controller.text = draft.text;
        _selectedPersona = personas.firstWhere(
          (p) => p.name == draft.personaName,
          orElse: () => personas.first,
        );
        _guidance = draft.guidance;
        _background = draft.background;
      } else {
        _currentDraftId = DateTime.now().millisecondsSinceEpoch.toString();
      }
    }
    setState(() => _restoringDraft = false);
    _loadDailyPrompt();
  }
  
  Future<void> _loadDailyPrompt() async {
    setState(() => _isPromptLoading = true);
    
    String? cachedPrompt = await _storage.getDailyPrompt(_selectedPersona.name);
    
    if (cachedPrompt != null) {
      if (mounted) setState(() {
        _currentPrompt = cachedPrompt;
        _isPromptLoading = false;
      });
      return;
    }

    try {
      List<String> freshPrompts = await _poemService.fetchWeeklyPrompts(
        _selectedPersona.name, 
        _selectedPersona.philosophy,
      );
      
      await _storage.saveWeeklyPrompts(_selectedPersona.name, freshPrompts);
      int dayIndex = (DateTime.now().weekday - 1) % freshPrompts.length;
      
      if (mounted) setState(() {
        _currentPrompt = freshPrompts[dayIndex];
      });
    } catch (e) {
      if (mounted) setState(() {
        _currentPrompt = "Reflect on quiet stillness and find your rhythm today.";
      });
    } finally {
      if (mounted) setState(() => _isPromptLoading = false);
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _persistDraft);
    // Clear analysis output when user starts editing again
    if (_structuralAnalysis != null) {
      setState(() => _structuralAnalysis = null);
    }
  }

  Future<void> _persistDraft() async {
    if (_controller.text.trim().isEmpty && _guidance == null) return;

    if (_isEditingCompletedEntry && widget.existingEntry != null) {
      final updatedEntry = HistoryEntry(
        id: _currentDraftId,
        timestamp: widget.existingEntry!.timestamp,
        personaName: _selectedPersona.name,
        personaEnglishName: _selectedPersona.englishName,
        transcript: widget.existingEntry!.transcript,
        poem: _controller.text,
        explanation: _guidance ?? '',
        background: _background ?? '',
        type: widget.existingEntry!.type,
        isFavorite: widget.existingEntry!.isFavorite,
      );
      await _storage.updateHistoryEntry(updatedEntry);
    } else {
      await _storage.saveDraft(
        WritingDraft(
          id: _currentDraftId,
          personaName: _selectedPersona.name,
          personaEnglishName: _selectedPersona.englishName,
          text: _controller.text,
          guidance: _guidance,
          background: _background,
          updatedAt: DateTime.now(),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _getGuidance() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loadingGuidance = true;
      _error = null;
      _structuralAnalysis = null; // Hide structure output if getting creative feedback
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

  Future<void> _analyzeStructure() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _analyzingStructure = true;
      _error = null;
    });

    try {
      final analysis = await _service.analyzeStructure(text);
      setState(() {
        _structuralAnalysis = analysis;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _analyzingStructure = false);
    }
  }

  Future<void> _markCompleted() async {
  final text = _controller.text.trim();

  if (text.isEmpty) {
    setState(() => _error = 'Write something before marking it complete.');
    return;
  }

  setState(() => _completing = true);

  HistoryEntry entry;

  if (_isEditingCompletedEntry && widget.existingEntry != null) {
    // Preserve old image when editing an existing poem
    entry = HistoryEntry(
      id: _currentDraftId,
      timestamp: widget.existingEntry!.timestamp,
      personaName: _selectedPersona.name,
      personaEnglishName: _selectedPersona.englishName,
      transcript: widget.existingEntry!.transcript,
      poem: text,
      explanation: _guidance ?? '',
      background: _background ?? '',
      type: widget.existingEntry!.type,
      isFavorite: widget.existingEntry!.isFavorite,
      imageUrl: widget.existingEntry!.imageUrl,
    );

    await _storage.updateHistoryEntry(entry);
  } else {
    // Generate Shan Shui image
    String? imageUrl;

    try {
      imageUrl = await _imageService.generateShanshuiPainting(text);
    } catch (e) {
      debugPrint("Image generation failed: $e");
    }

    entry = HistoryEntry(
      id: _currentDraftId,
      timestamp: DateTime.now(),
      personaName: _selectedPersona.name,
      personaEnglishName: _selectedPersona.englishName,
      transcript: text,
      poem: text,
      explanation: _guidance ?? '',
      background: _background ?? '',
      type: 'written',
      imageUrl: imageUrl,
    );

    await _storage.addHistoryEntry(entry);
    await _storage.deleteDraft(_currentDraftId);
  }

  if (!mounted) return;

  setState(() => _completing = false);

  _controller.removeListener(_onTextChanged);

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PoemScreen(entry: entry),
    ),
  );

  _startNewDraftWorkspace(saveCurrent: false);
}

  Future<void> _startNewDraftWorkspace({bool saveCurrent = true}) async {
    _controller.removeListener(_onTextChanged);
    if (saveCurrent) {
      // Save whatever is currently in the notebook before wiping it, so
      // tapping "New Blank Page" behaves the same as navigating away.
      await _persistDraft();
    }
    _controller.clear();
    setState(() {
      _currentDraftId = DateTime.now().millisecondsSinceEpoch.toString();
      _isEditingCompletedEntry = false;
      _guidance = null;
      _background = null;
      _structuralAnalysis = null;
      _error = null;
    });
    _controller.addListener(_onTextChanged);
  }

  Future<void> _showDraftsManager() async {
    final drafts = await _storage.getDrafts();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.inkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text('Saved Notebook Drafts', style: TextStyle(fontSize: 15)),
                    automaticallyImplyLeading: false,
                    actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
                  ),
                  if (drafts.isEmpty)
                    const Padding(padding: EdgeInsets.all(40), child: Text('No active drafts.', style: TextStyle(color: Colors.grey)))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: drafts.length,
                        itemBuilder: (context, index) {
                          final d = drafts[index];
                          final isCurrent = d.id == _currentDraftId && !_isEditingCompletedEntry;
                          return ListTile(
                            title: Text(
                              d.text.trim().isEmpty ? '(Empty Page)' : d.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isCurrent ? AppColors.gold : AppColors.paper),
                            ),
                            subtitle: Text('${d.personaName} · ${d.updatedAt.month}/${d.updatedAt.day}', style: const TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.crimson),
                              onPressed: () async {
                                await _storage.deleteDraft(d.id);
                                drafts.removeWhere((element) => element.id == d.id);
                                setModalState(() {});
                                if (isCurrent) _startNewDraftWorkspace();
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _controller.removeListener(_onTextChanged);
                              setState(() {
                                _isEditingCompletedEntry = false;
                                _currentDraftId = d.id;
                                _controller.text = d.text;
                                _selectedPersona = personas.firstWhere((p) => p.name == d.personaName, orElse: () => personas.first);
                                _guidance = d.guidance;
                                _background = d.background;
                                _structuralAnalysis = null;
                              });
                              _controller.addListener(_onTextChanged);
                              _loadDailyPrompt(); 
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
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
        title: Text(_isEditingCompletedEntry ? 'Editing Poem' : '落笔为诗'),
        actions: [
          AnimatedOpacity(
            opacity: _justSaved ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Center(
              child: Text('Saved', style: TextStyle(color: AppColors.jade.withOpacity(0.8), fontSize: 12)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.folder_open_outlined, color: AppColors.paper.withOpacity(0.7)),
            tooltip: 'View Drafts Folder',
            onPressed: _showDraftsManager,
          ),
          IconButton(
            icon: Icon(Icons.note_add_outlined, color: AppColors.paper.withOpacity(0.7)),
            tooltip: 'New Blank Page',
            onPressed: () => _startNewDraftWorkspace(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mentor', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              _PersonaPicker(
                selected: _selectedPersona,
                onChanged: (p) {
                  setState(() => _selectedPersona = p);
                  _persistDraft();
                  _loadDailyPrompt(); 
                },
              ),
              const SizedBox(height: 24),
              PoeticPromptBanner(
                promptText: _currentPrompt,
                personaName: _selectedPersona.name,
                isLoading: _isPromptLoading,
              ),
              const SizedBox(height: 20),
              if (_background != null && _background!.isNotEmpty) ...[
                _BackgroundCard(text: _background!),
                const SizedBox(height: 20),
              ],
              Text(_isEditingCompletedEntry ? 'Modify Completed Poem' : 'Your notebook',
                  style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 10),
              _NotebookField(controller: _controller),
              const SizedBox(height: 18),
              
              _ActionButtons(
                loadingGuidance: _loadingGuidance,
                analyzingStructure: _analyzingStructure,
                completing: _completing,
                onGetGuidance: _getGuidance,
                onAnalyzeStructure: _analyzeStructure,
                onMarkCompleted: _markCompleted,
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.crimson, fontSize: 13)),
              ],

              if (_structuralAnalysis != null) ...[
                const SizedBox(height: 28),
                _AnalysisCard(analysis: _structuralAnalysis!),
              ],

              if (_guidance != null && _guidance!.isNotEmpty) ...[
                const SizedBox(height: 28),
                Container(height: 1, color: AppColors.inkBorder),
                const SizedBox(height: 20),
                // 🌟 NEW: Speaker icon inline with the Guidance header
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.violet.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text('Guidance', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _isPlayingGuidance ? Icons.stop_rounded : Icons.volume_up_rounded,
                        color: AppColors.violet.withOpacity(0.8),
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        _audioService.togglePlayback(_guidance!);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_guidance!, style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.6)),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final PoemAnalysis analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(Icons.rule_rounded, size: 16, color: AppColors.gold.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                'Structural Analysis: ${analysis.structureType}',
                style: TextStyle(color: AppColors.gold.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(analysis.tonalFeedback, style: const TextStyle(color: AppColors.paper, fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Text(analysis.rhymeFeedback, style: const TextStyle(color: AppColors.paper, fontSize: 14, height: 1.5)),
          
          if (analysis.ruleBreaks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Rule Violations:', style: TextStyle(color: AppColors.crimson, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...analysis.ruleBreaks.map((rule) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.crimson)),
                  Expanded(child: Text(rule, style: TextStyle(color: AppColors.crimson.withOpacity(0.9), fontSize: 14))),
                ],
              ),
            )),
          ] else ...[
            const SizedBox(height: 16),
            const Text('✨ Structure is technically flawless.', style: TextStyle(color: AppColors.jade, fontSize: 13, fontWeight: FontWeight.w600)),
          ]
        ],
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
                style: const TextStyle(color: AppColors.paper, fontSize: 16, height: 1.8),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'Begin your poem, reflection, or idea here...\n\nThis page saves itself as you write.',
                  hintStyle: TextStyle(color: AppColors.paper.withOpacity(0.28), height: 1.8),
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
  final bool analyzingStructure;
  final bool completing;
  
  final VoidCallback onGetGuidance;
  final VoidCallback onAnalyzeStructure;
  final VoidCallback onMarkCompleted;

  const _ActionButtons({
    required this.loadingGuidance, 
    required this.analyzingStructure, 
    required this.completing, 
    required this.onGetGuidance, 
    required this.onAnalyzeStructure, 
    required this.onMarkCompleted
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = 13.0;
    final vPad = 14.0;

    final guidanceButton = OutlinedButton(
      onPressed: (loadingGuidance || analyzingStructure) ? null : onGetGuidance,
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: BorderSide(color: AppColors.gold.withOpacity(0.5)), padding: EdgeInsets.symmetric(vertical: vPad), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: loadingGuidance ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)) : FittedBox(child: Text('Get Guidance', style: TextStyle(fontSize: fontSize))),
    );
    
    final analyzeButton = OutlinedButton(
      onPressed: (loadingGuidance || analyzingStructure) ? null : onAnalyzeStructure,
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: BorderSide(color: AppColors.gold.withOpacity(0.5)), padding: EdgeInsets.symmetric(vertical: vPad), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: analyzingStructure ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)) : FittedBox(child: Text('Analyze Structure', style: TextStyle(fontSize: fontSize))),
    );

    final completeButton = ElevatedButton(
      onPressed: completing ? null : onMarkCompleted,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.seal, foregroundColor: AppColors.paper, padding: EdgeInsets.symmetric(vertical: vPad), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: completing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.paper)) : FittedBox(child: Text('Mark as Completed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize))),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: guidanceButton),
            const SizedBox(width: 12),
            Expanded(child: analyzeButton),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: completeButton,
        ),
      ],
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
      decoration: BoxDecoration(color: AppColors.violet.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.violet.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: isNarrow ? 14 : 16, color: AppColors.violet.withOpacity(0.9)),
              const SizedBox(width: 6),
              Flexible(child: Text('References & Background', style: TextStyle(color: AppColors.violet.withOpacity(0.9), fontSize: isNarrow ? 11.5 : 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: AppColors.paper.withOpacity(0.8), fontSize: isNarrow ? 12.5 : 13.5, height: 1.55)),
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
            labelStyle: TextStyle(color: isSelected ? AppColors.gold : AppColors.paper.withOpacity(0.7), fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
            side: BorderSide(color: isSelected ? AppColors.gold.withOpacity(0.5) : AppColors.inkBorder),
          );
        },
      ),
    );
  }
}