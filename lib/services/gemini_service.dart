import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/persona.dart';
import '../models/poem_result.dart';
import 'storage_service.dart';

class GeminiPoemService {
  static const _model = 'gemini-2.5-flash';

  final StorageService _storage = StorageService();

  Future<PoemResult> generateFromAudio(String audioFilePath) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'No Gemini API key set. Go to Settings and add your key.',
      );
    }

    final persona = personas[Random().nextInt(personas.length)];

    final bytes = await File(audioFilePath).readAsBytes();
    final base64Audio = base64Encode(bytes);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are a master poet channeling the ${persona.name} (${persona.englishName}) school of Chinese thought.
Philosophy and imagery to draw on: ${persona.philosophy}

Step 1: Transcribe what the speaker says in the audio, in its original language.
Step 2: Detect the language of the transcript.
Step 3: Write a poem suited to their situation, strictly in that persona's philosophy and voice.
  - If the transcript is in Chinese: write a classical Jueju (绝句) or Ci (词) with proper rhyme, plus a modern-Chinese explanation covering both the poem's meaning and how it reflects this persona's philosophy.
  - If the transcript is in English: write a classical English quatrain or short sonnet (iambic meter), plus a modern-English explanation covering both the poem's meaning and how it reflects this persona's philosophy.

Respond ONLY with raw JSON, no markdown fences, no extra commentary, in exactly this shape:
{"transcript": "...", "poem": "...", "explanation": "..."}
''';

    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'audio/m4a',
                  'data': base64Audio,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini. Raw: ${response.body}');
    }

    final text = candidates[0]['content']['parts'][0]['text'] as String;
    final parsed = jsonDecode(text) as Map<String, dynamic>;

    return PoemResult(
      personaName: persona.name,
      personaEnglishName: persona.englishName,
      transcript: parsed['transcript'] as String? ?? '',
      poem: parsed['poem'] as String? ?? '',
      explanation: parsed['explanation'] as String? ?? '',
    );
  }
}