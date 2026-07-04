import 'package:flutter_tts/flutter_tts.dart';

class AudioMentorService {
  final FlutterTts _tts = FlutterTts();
  bool isPlaying = false;
  
  // Callback listener to safely reflect status updates back to the UI widgets
  Function(bool)? onStateChanged;

  AudioMentorService() {
    _initTts();
  }

  Future<void> _initTts() async {
    // 🌟 Configured voice adjustments for a wise, meditative pace
    await _tts.setSpeechRate(0.35); // Measured, slow pacing
    await _tts.setPitch(0.85);      // Deeper, traditional timber
    
    // Engine lifecycle hooks to reset icons and toggle buttons automatically
    _tts.setStartHandler(() {
      isPlaying = true;
      onStateChanged?.call(true);
    });
    
    _tts.setCompletionHandler(() {
      isPlaying = false;
      onStateChanged?.call(false);
    });
    
    _tts.setCancelHandler(() {
      isPlaying = false;
      onStateChanged?.call(false);
    });
  }

  Future<void> togglePlayback(String text) async {
    if (isPlaying) {
      await stop();
    } else {
      await play(text);
    }
  }

  Future<void> play(String text) async {
    // Auto-detect language: uses Mandarin zh-CN if standard Hanzi symbols are matched
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    await _tts.setLanguage(isChinese ? "zh-CN" : "en-US");
    
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}