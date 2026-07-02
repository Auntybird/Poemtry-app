import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/history_entry.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';
import 'poem_screen.dart';
import 'settings_screen.dart';

enum _AppState { idle, recording, processing }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recorder = AudioRecorder();
  final _geminiService = GeminiPoemService();
  final _storage = StorageService();

  _AppState _state = _AppState.idle;
  String? _recordingPath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _onMicTapped() async {
    switch (_state) {
      case _AppState.idle:
        await _startRecording();
      case _AppState.recording:
        await _stopAndGenerate();
      case _AppState.processing:
        break;
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showError('Microphone permission is required to record.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);

    setState(() {
      _state = _AppState.recording;
      _recordingPath = path;
    });
  }

  Future<void> _stopAndGenerate() async {
    final path = await _recorder.stop();
    if (path == null && _recordingPath == null) {
      _showError('Recording failed. Please try again.');
      setState(() => _state = _AppState.idle);
      return;
    }

    setState(() => _state = _AppState.processing);

    try {
      final result = await _geminiService.generateFromAudio(
        path ?? _recordingPath!,
      );

      await _storage.addHistoryEntry(
        HistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          personaName: result.personaName,
          personaEnglishName: result.personaEnglishName,
          transcript: result.transcript,
          poem: result.poem,
          explanation: result.explanation,
        ),
      );

      if (!mounted) return;
      setState(() => _state = _AppState.idle);

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PoemScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _AppState.idle);
      _showError('Something went wrong: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.inkSurfaceLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        actions: [
          _TopIconButton(
            icon: Icons.bar_chart_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          _TopIconButton(
            icon: Icons.history_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          _TopIconButton(
            icon: Icons.settings_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '诸子百家',
                style: TextStyle(
                  color: AppColors.paper,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 10),
              Container(width: 36, height: 1, color: AppColors.gold.withOpacity(0.6)),
              const SizedBox(height: 14),
              Text(
                _statusLabel(),
                style: TextStyle(
                  color: AppColors.paper.withOpacity(0.55),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 70),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [_micColor().withOpacity(0.16), Colors.transparent],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _onMicTapped,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _micColor(),
                        border: Border.all(color: AppColors.paper.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: _micColor().withOpacity(0.45),
                            blurRadius: _state == _AppState.recording ? 34 : 14,
                            spreadRadius: _state == _AppState.recording ? 6 : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _state == _AppState.processing
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: AppColors.paper,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Icon(
                                _state == _AppState.recording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: AppColors.paper,
                                size: 44,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel() {
    switch (_state) {
      case _AppState.idle:
        return 'Tap to speak your situation';
      case _AppState.recording:
        return 'Listening... tap to stop';
      case _AppState.processing:
        return 'Composing your poem...';
    }
  }

  Color _micColor() {
    switch (_state) {
      case _AppState.idle:
        return AppColors.inkSurfaceLight;
      case _AppState.recording:
        return AppColors.seal;
      case _AppState.processing:
        return AppColors.gold;
    }
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inkSurface),
          child: Icon(icon, color: AppColors.paper.withOpacity(0.75), size: 20),
        ),
      ),
    );
  }
}