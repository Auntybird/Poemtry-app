import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// Synthesizes speech using Gemini's native TTS models. Only Google's 30
/// prebuilt, non-celebrity voices are ever used here (e.g. "Kore", "Puck",
/// "Charon") — this app does not clone or impersonate any real person's
/// voice.
///
/// This is a "best effort, free-tier" feature: it returns null on ANY
/// failure (no key, network issue, rate limit, quota exhausted, or the
/// preview model changing/disappearing), so callers should always have a
/// guaranteed-free fallback (on-device TTS) ready to go.
class GeminiTtsService {
  final StorageService _storage = StorageService();

  // Preview model as of mid-2026. If Google renames/retires this, add the
  // new name here — resolveModelCandidates-style fallback isn't used since
  // TTS-capable models are less interchangeable than text models.
  static const String _model = 'gemini-2.5-flash-preview-tts';

  /// Returns raw 16-bit mono PCM audio at 24kHz, or null if synthesis
  /// failed for any reason. Never throws.
  Future<Uint8List?> synthesizeSpeech(String text, {required String voiceName}) async {
    try {
      final apiKey = await _storage.getApiKey();
      if (apiKey == null || apiKey.isEmpty) return null;

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
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

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final audioData = parts[0]['inlineData']?['data'] as String?;
      if (audioData == null) return null;

      return base64Decode(audioData);
    } catch (_) {
      // Any failure (network, parsing, rate limit, etc.) — caller falls
      // back to on-device TTS. This service never surfaces an error itself.
      return null;
    }
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