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
  // (only relevant when falling back from/to device TTS).
  Function(String message)? onVoiceUnavailable;

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

  Future<void> togglePlayback(String text) async {
    if (isPlaying) {
      await stop();
    } else {
      await play(text);
    }
  }

  Future<void> play(String text) async {
    final useAiVoice = await _storage.getUseAiVoice();

    if (useAiVoice) {
      final voiceName = await _storage.getAiVoiceName();
      final pcm = await _geminiTts.synthesizeSpeech(text, voiceName: voiceName);

      if (pcm != null) {
        final wavBytes = _geminiTts.wrapPcmAsWav(pcm);
        try {
          await _player.play(BytesSource(wavBytes));
          return; // Success — done, no need to fall back.
        } catch (_) {
          // Playback failed even though synthesis succeeded (rare) — fall
          // through to on-device TTS below rather than staying silent.
        }
      }
      // Gemini synthesis failed (no key, network, rate limit, quota,
      // model unavailable, etc.) — fall back to the guaranteed-free
      // on-device voice below. No error shown; this is expected/normal
      // for a free-tier-dependent optional feature.
    }

    await _playOnDevice(text);
  }

  Future<void> _playOnDevice(String text) async {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);

    if (!isChinese) {
      await _tts.setLanguage('en-US');
      await _tts.speak(text);
      return;
    }

    // 🌟 Cantonese first (zh-HK), falling back to Mandarin (zh-CN) if that
    // voice data isn't installed on this device.
    final candidates = ['zh-HK', 'zh-CN'];

    for (final langCode in candidates) {
      final available = await _tts.isLanguageAvailable(langCode);
      final isAvailable = available == true || available == 1;

      if (isAvailable) {
        await _tts.setLanguage(langCode);
        await _tts.speak(text);
        return;
      }
    }

    onVoiceUnavailable?.call(
      'No Chinese voice is installed on this device. Go to your phone\'s '
      'Settings → Text-to-speech (or Languages & input → Text-to-speech '
      'output) and download the Chinese (Cantonese or Mandarin) voice data.',
    );
    isPlaying = false;
    onStateChanged?.call(false);
  }

  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }
}