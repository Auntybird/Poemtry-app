import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/history_entry.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
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
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14151A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
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
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusLabel(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 64),
              GestureDetector(
                onTap: _onMicTapped,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _micColor(),
                    boxShadow: [
                      BoxShadow(
                        color: _micColor().withOpacity(0.4),
                        blurRadius: _state == _AppState.recording ? 30 : 12,
                        spreadRadius: _state == _AppState.recording ? 6 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _state == _AppState.processing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            _state == _AppState.recording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                  ),
                ),
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
        return const Color(0xFF5A5F73);
      case _AppState.recording:
        return const Color(0xFFC0392B);
      case _AppState.processing:
        return const Color(0xFF8E7CC3);
    }
  }
}