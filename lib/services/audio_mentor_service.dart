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

  // 🌟 Incremented on every play()/stop() call. A play() request checks this
  // after each await — if it's changed (a newer play/stop call came in while
  // we were waiting on the network or the engine), we abandon this request
  // instead of playing stale/late audio on top of whatever's current.
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
  /// already playing correctly switches to the new text instead of doing
  /// nothing (which is what the old togglePlayback-only approach did).
  Future<void> play(String text) async {
    final int myToken = ++_playToken;

    // Stop both engines unconditionally before starting anything new, so
    // switching sources never results in overlapping audio.
    await _tts.stop();
    await _player.stop();
    if (myToken != _playToken) return; // superseded while stopping

    final useAiVoice = await _storage.getUseAiVoice();
    if (myToken != _playToken) return; // superseded while reading prefs

    if (useAiVoice) {
      final voiceName = await _storage.getAiVoiceName();
      if (myToken != _playToken) return;

      final pcm = await _geminiTts.synthesizeSpeech(text, voiceName: voiceName);
      // This is the critical check: if the user tapped stop, tapped a
      // different play button, or changed the voice while this network
      // call was in flight, myToken no longer matches _playToken — so we
      // discard this result instead of playing it late.
      if (myToken != _playToken) return;

      if (pcm != null) {
        final wavBytes = _geminiTts.wrapPcmAsWav(pcm);
        try {
          if (myToken != _playToken) return;
          await _player.play(BytesSource(wavBytes));
          return;
        } catch (_) {
          // fall through to on-device below
        }
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
    _playToken++; // invalidate any in-flight play() request immediately
    await _tts.stop();
    await _player.stop();
    isPlaying = false;
    onStateChanged?.call(false);
  }
}