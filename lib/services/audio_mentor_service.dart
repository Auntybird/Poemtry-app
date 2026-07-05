import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'gemini_tts_service.dart';
import 'storage_service.dart';

class AudioMentorService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final GeminiTtsService _geminiTts = GeminiTtsService();
  final StorageService _storage = StorageService();

  bool isPlaying = false;

  // Callback listener to safely reflect status updates back to the UI widgets
  Function(bool)? onStateChanged;

  // 🌟 Fired when the on-device voice is missing for the needed language
  Function(String message)? onVoiceUnavailable;

  // 🌟 Fired whenever AI Voice is enabled but falls back to the device voice
  // for this playback — with the real reason, so it's never a silent,
  // confusing "why didn't it change" situation.
  Function(String reason)? onAiVoiceFallback;

  // 🌟 Incremented on every play()/stop() call. See play() for how this is
  // used to discard stale/late results.
  int _playToken = 0;

  AudioMentorService() {
    _initTts();
    _initPlayer();
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

  void _initPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      isPlaying = playing;
      onStateChanged?.call(playing);
    });
    _player.onPlayerComplete.listen((_) {
      isPlaying = false;
      onStateChanged?.call(false);
    });
  }

  /// Kept for compatibility, but callers that need to switch between
  /// different texts (e.g. poem vs. guidance) should call [play] directly
  /// instead — see the note in play() for why.
  Future<void> togglePlayback(String text) async {
    if (isPlaying) {
      await stop();
    } else {
      await play(text);
    }
  }

  /// Always fully stops whatever's currently playing (on both engines) and
  /// starts fresh — so calling play() with new text while something else is
  /// already playing correctly switches to the new text.
  Future<void> play(String text) async {
    final int myToken = ++_playToken;

    await _tts.stop();
    await _player.stop();
    if (myToken != _playToken) return;

    final useAiVoice = await _storage.getUseAiVoice();
    if (myToken != _playToken) return;

    if (useAiVoice) {
      final voiceName = await _storage.getAiVoiceName();
      if (myToken != _playToken) return;

      final pcm = await _geminiTts.synthesizeSpeech(text, voiceName: voiceName);
      if (myToken != _playToken) return;

      if (pcm != null) {
        final wavBytes = _geminiTts.wrapPcmAsWav(pcm);
        try {
          if (myToken != _playToken) return;
          await _player.play(BytesSource(wavBytes));
          return;
        } catch (e) {
          if (myToken != _playToken) return;
          onAiVoiceFallback?.call('AI voice playback failed ($e). Using device voice instead.');
          // fall through to on-device below
        }
      } else {
        // Synthesis itself failed — surface why, then fall back.
        if (myToken != _playToken) return;
        onAiVoiceFallback?.call(
          'AI voice unavailable right now (${_geminiTts.lastFailureReason ?? 'unknown reason'}). Using device voice instead.',
        );
      }
    }

    if (myToken != _playToken) return;
    await _playOnDevice(text, myToken);
  }

  Future<void> _playOnDevice(String text, int token) async {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);

    if (!isChinese) {
      if (token != _playToken) return;
      await _tts.setLanguage('en-US');
      if (token != _playToken) return;
      await _tts.speak(text);
      return;
    }

    // 🌟 Cantonese first (zh-HK), falling back to Mandarin (zh-CN) if that
    // voice data isn't installed on this device.
    final candidates = ['zh-HK', 'zh-CN'];

    for (final langCode in candidates) {
      final available = await _tts.isLanguageAvailable(langCode);
      if (token != _playToken) return;
      final isAvailable = available == true || available == 1;

      if (isAvailable) {
        await _tts.setLanguage(langCode);
        if (token != _playToken) return;
        await _tts.speak(text);
        return;
      }
    }

    if (token != _playToken) return;
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
    await _player.stop();
    isPlaying = false;
    onStateChanged?.call(false);
  }
}