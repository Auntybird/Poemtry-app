import 'package:flutter_tts/flutter_tts.dart';

class AudioMentorService {
  final FlutterTts _tts = FlutterTts();
  bool isPlaying = false;

  // Callback listener to safely reflect status updates back to the UI widgets
  Function(bool)? onStateChanged;

  // 🌟 Fired when the on-device voice is missing for the needed language
  Function(String message)? onVoiceUnavailable;

  // 🌟 Incremented on every play()/stop() call, so a stale in-flight request
  // (e.g. still waiting on isLanguageAvailable) can detect it's been
  // superseded and abandon itself instead of speaking late/on top of
  // whatever's currently happening.
  int _playToken = 0;

  AudioMentorService() {
    _initTts();
  }

  Future<void> _initTts() async {
    // 🌟 Configured voice adjustments for a wise, meditative pace
    await _tts.setSpeechRate(0.35); // Measured, slow pacing
    await _tts.setPitch(0.85);      // Deeper, traditional timber

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

  /// Kept for compatibility with older call sites, but callers that need to
  /// switch between different texts (e.g. poem vs. guidance) should call
  /// [play] directly instead — it always stops whatever's playing first, so
  /// it correctly switches rather than just toggling the current one off.
  Future<void> togglePlayback(String text) async {
    if (isPlaying) {
      await stop();
    } else {
      await play(text);
    }
  }

  Future<void> play(String text) async {
    final int myToken = ++_playToken;

    await _tts.stop();
    if (myToken != _playToken) return; // superseded while stopping

    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);

    if (!isChinese) {
      await _tts.setLanguage('en-US');
      if (myToken != _playToken) return;
      await _tts.speak(text);
      return;
    }

    // 🌟 Cantonese first (zh-HK), falling back to Mandarin (zh-CN) if that
    // voice data isn't installed on this device.
    final candidates = ['zh-HK', 'zh-CN'];

    for (final langCode in candidates) {
      final available = await _tts.isLanguageAvailable(langCode);
      if (myToken != _playToken) return;
      final isAvailable = available == true || available == 1;

      if (isAvailable) {
        await _tts.setLanguage(langCode);
        if (myToken != _playToken) return;
        await _tts.speak(text);
        return;
      }
    }

    if (myToken != _playToken) return;
    onVoiceUnavailable?.call(
      'No Chinese voice is installed on this device. Go to your phone\'s '
      'Settings → Text-to-speech (or Languages & input → Text-to-speech '
      'output) and download the Chinese (Cantonese or Mandarin) voice data.',
    );
    isPlaying = false;
    onStateChanged?.call(false);
  }

  Future<void> stop() async {
    _playToken++;
    await _tts.stop();
    isPlaying = false;
    onStateChanged?.call(false);
  }
}