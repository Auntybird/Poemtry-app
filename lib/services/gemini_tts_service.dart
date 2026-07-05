import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// Synthesizes speech using Gemini's native TTS models. Only Google's 30
/// prebuilt, non-celebrity voices are ever used here (e.g. "Kore", "Puck",
/// "Charon") — this app does not clone or impersonate any real person's
/// voice.
///
/// This is a "best effort, free-tier" feature: [synthesizeSpeech] returns
/// null on ANY failure (no key, network issue, rate limit, quota exhausted,
/// or a preview model changing/disappearing), so callers should always have
/// a guaranteed-free fallback (on-device TTS) ready to go. [lastFailureReason]
/// is set on failure purely for optional debugging/UI messaging — it's not
/// required for the fallback logic to work.
class GeminiTtsService {
  final StorageService _storage = StorageService();

  // Google's preview TTS models get renamed/retired periodically (the same
  // thing happened to gemini-2.0-flash for text generation). We try the
  // newest known name first, then fall back to older ones, so a rename
  // doesn't silently break this feature again.
  static const List<String> _modelCandidates = [
    'gemini-3.1-flash-tts-preview',
    'gemini-2.5-flash-preview-tts',
  ];

  /// Human-readable reason the last synthesizeSpeech() call failed, or null
  /// if it succeeded / hasn't been called yet. Useful for surfacing a
  /// message to the user instead of a silent, confusing fallback.
  String? lastFailureReason;

  /// Returns raw 16-bit mono PCM audio at 24kHz, or null if synthesis
  /// failed for any reason. Never throws.
  Future<Uint8List?> synthesizeSpeech(String text, {required String voiceName}) async {
    lastFailureReason = null;

    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      lastFailureReason = 'No Gemini API key set.';
      return null;
    }

    Object? lastError;

    for (final model in _modelCandidates) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http.post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': text},
                ],
              },
            ],
            'generationConfig': {
              'responseModalities': ['AUDIO'],
              'speechConfig': {
                'voiceConfig': {
                  'prebuiltVoiceConfig': {'voiceName': voiceName},
                },
              },
            },
          }),
        );

        if (response.statusCode != 200) {
          lastError = 'Model $model failed (${response.statusCode}): ${response.body}';
          // 404 usually means this model name no longer exists — try the
          // next candidate. Other errors (429/503/etc.) also worth trying
          // the next candidate rather than giving up immediately.
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          lastError = 'Model $model returned no candidates.';
          continue;
        }

        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          lastError = 'Model $model returned no audio parts.';
          continue;
        }

        final audioData = parts[0]['inlineData']?['data'] as String?;
        if (audioData == null) {
          lastError = 'Model $model returned no inline audio data.';
          continue;
        }

        return base64Decode(audioData);
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    lastFailureReason = lastError?.toString() ?? 'Unknown TTS failure.';
    return null;
  }

  /// Gemini returns headerless raw PCM. Standard audio players expect a WAV
  /// container, so we wrap it with a minimal 44-byte header.
  Uint8List wrapPcmAsWav(Uint8List pcmData, {int sampleRate = 24000}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcmData.length;
    final chunkSize = 36 + dataLength;

    final header = BytesBuilder();
    void writeString(String s) => header.add(s.codeUnits);
    void writeUint32(int v) => header.add([
          v & 0xff,
          (v >> 8) & 0xff,
          (v >> 16) & 0xff,
          (v >> 24) & 0xff,
        ]);
    void writeUint16(int v) => header.add([v & 0xff, (v >> 8) & 0xff]);

    writeString('RIFF');
    writeUint32(chunkSize);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16); // PCM header size
    writeUint16(1); // audio format = PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(dataLength);
    header.add(pcmData);

    return header.toBytes();
  }
}