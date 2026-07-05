import 'package:flutter_tts/flutter_tts.dart';

class AudioMentorService {
  final FlutterTts _tts = FlutterTts();
  bool isPlaying = false;

  // Callback listener to safely reflect status updates back to the UI widgets
  Function(bool)? onStateChanged;

  // 🌟 Fired when the requested voice/language isn't installed on this device,
  // so the UI can tell the user why nothing played instead of it being silent.
  Function(String message)? onVoiceUnavailable;

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

  /// Returns true if playback actually started. Callers can check this to
  /// show a message when it doesn't (e.g. missing voice data on device).
  Future<bool> play(String text) async {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);

    if (!isChinese) {
      await _tts.setLanguage('en-US');
      await _tts.speak(text);
      return true;
    }

    // 🌟 Cantonese first (zh-HK), since that's the requested voice. Some
    // devices only have Mandarin (zh-CN) voice data installed though, so we
    // fall back to that rather than staying silent, and only give up (with
    // a clear message) if neither is available.
    final candidates = ['zh-HK', 'zh-CN'];

    for (final langCode in candidates) {
      final available = await _tts.isLanguageAvailable(langCode);
      // isLanguageAvailable can return a bool or an int (1/0/-1) depending on
      // platform, so check loosely rather than assuming a bool.
      final isAvailable = available == true || available == 1;

      if (isAvailable) {
        await _tts.setLanguage(langCode);
        await _tts.speak(text);
        return true;
      }
    }

    // Neither Cantonese nor Mandarin voice data is installed on this device.
    onVoiceUnavailable?.call(
      'No Chinese voice is installed on this device. Go to your phone\'s '
      'Settings → Text-to-speech (or Languages & input → Text-to-speech '
      'output) and download the Chinese (Cantonese or Mandarin) voice data.',
    );
    isPlaying = false;
    onStateChanged?.call(false);
    return false;
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}