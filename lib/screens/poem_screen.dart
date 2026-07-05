import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/history_entry.dart';
import '../services/storage_service.dart';
import '../services/audio_mentor_service.dart'; // 🌟 Added
import '../theme/app_theme.dart';
import '../widgets/poem_export_dialog.dart';

class PoemScreen extends StatefulWidget {
  final HistoryEntry entry;

  const PoemScreen({super.key, required this.entry});

  @override
  State<PoemScreen> createState() => _PoemScreenState();
}

class _PoemScreenState extends State<PoemScreen> {
  final _storage = StorageService();
  final _audioService = AudioMentorService(); // 🌟 Added
  
  late bool _isFavorite;
  bool _isPlayingPoem = false;
  bool _isPlayingGuidance = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.entry.isFavorite; //
    
    // 🌟 Update visual indicators instantly when playback starts or stops
    _audioService.onStateChanged = (isPlaying) {
      if (mounted) {
        setState(() {
          if (!isPlaying) {
            _isPlayingPoem = false;
            _isPlayingGuidance = false;
          }
        });
      }
    };

    // 🌟 Surface missing voice-data errors instead of silent failure
    _audioService.onVoiceUnavailable = (message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.inkSurfaceLight,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    _audioService.stop(); // Safe guard: halts playback if user hits back/closes screen
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    await _storage.toggleFavorite(widget.entry.id); //
    setState(() => _isFavorite = !_isFavorite); //
  }

  void _copyToClipboard() {
    final text = '${widget.entry.poem}\n\n${widget.entry.explanation}'; //
    Clipboard.setData(ClipboardData(text: text)); //
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), backgroundColor: AppColors.inkSurfaceLight), //
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry; //
    return Scaffold(
      backgroundColor: AppColors.ink, //
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: AppColors.paper.withOpacity(0.7), size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PoemExportDialog(entry: widget.entry),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, color: AppColors.paper.withOpacity(0.7), size: 20), //
            onPressed: _copyToClipboard, //
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, //
              color: _isFavorite ? AppColors.seal : AppColors.paper.withOpacity(0.6), //
            ),
            onPressed: _toggleFavorite, //
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), //
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, //
            children: [
              Row(
                children: [
                  _PersonaTag(name: entry.personaName, english: entry.personaEnglishName), //
                  const SizedBox(width: 8), //
                  Icon(
                    entry.type == 'written' ? Icons.edit_note_rounded : Icons.mic_rounded, //
                    size: 16, //
                    color: AppColors.paper.withOpacity(0.4),
                  ),
                  const Spacer(),
                  // 🌟 Main Playback node for scanning poem rhythms
                  IconButton(
                    icon: Icon(
                      _isPlayingPoem ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      color: AppColors.gold,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPlayingPoem = !_isPlayingPoem;
                        _isPlayingGuidance = false;
                      });
                      _audioService.togglePlayback(entry.poem);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                entry.poem, //
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

              if (entry.type == 'voice') ...[
                Text('You said', style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  entry.transcript,
                  style: TextStyle(color: AppColors.paper.withOpacity(0.75), fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
                ),
                const SizedBox(height: 28),
              ],

              if (entry.explanation.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      entry.type == 'written' ? 'Guidance received' : 'Meaning',
                      style: TextStyle(color: AppColors.paper.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
                    ),
                    const Spacer(),
                    // 🌟 Secondary voice node for philosophical interpretation
                    IconButton(
                      icon: Icon(
                        _isPlayingGuidance ? Icons.stop_rounded : Icons.volume_up_rounded,
                        color: AppColors.paper.withOpacity(0.6),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPlayingGuidance = !_isPlayingGuidance;
                          _isPlayingPoem = false;
                        });
                        _audioService.togglePlayback(entry.explanation);
                      },
                    ),
                  ],
                ),
                Text(entry.explanation, style: const TextStyle(color: AppColors.paper, fontSize: 15, height: 1.6)),
                const SizedBox(height: 28),
              ],

              if (entry.background.isNotEmpty) _ReferenceSection(text: entry.background),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  final String text;
  const _ReferenceSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.violet.withOpacity(0.3)), //
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, //
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 16, color: AppColors.violet.withOpacity(0.9)), //
              const SizedBox(width: 6), //
              Text(
                'References & Background', //
                style: TextStyle(color: AppColors.violet.withOpacity(0.9), fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5), //
              ),
            ],
          ),
          const SizedBox(height: 8), //
          Text(text, style: TextStyle(color: AppColors.paper.withOpacity(0.8), fontSize: 13.5, height: 1.55)), //
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), //
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.14), //
        borderRadius: BorderRadius.circular(20), //
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Text(
        '$name · $english',
        style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}