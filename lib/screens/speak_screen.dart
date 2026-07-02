import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/history_entry.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'poem_screen.dart';

enum _AppState { idle, recording, processing }

class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> {
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
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      final result = await _geminiService.generateFromAudio(path ?? _recordingPath!);

      final entry = HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        personaName: result.personaName,
        personaEnglishName: result.personaEnglishName,
        transcript: result.transcript,
        poem: result.poem,
        explanation: result.explanation,
        background: result.background, // Added field
        type: 'voice',
      );
      await _storage.addHistoryEntry(entry);

      if (!mounted) return;
      setState(() => _state = _AppState.idle);

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PoemScreen(entry: entry)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _AppState.idle);
      _showError('Something went wrong: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.inkSurfaceLight),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _statusLabel(),
                style: TextStyle(color: AppColors.paper.withOpacity(0.6), fontSize: 15),
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
                      gradient: RadialGradient(colors: [_micColor().withOpacity(0.16), Colors.transparent]),
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
                                child: CircularProgressIndicator(color: AppColors.paper, strokeWidth: 2.4),
                              )
                            : Icon(
                                _state == _AppState.recording ? Icons.stop_rounded : Icons.mic_rounded,
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