import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/persona.dart';
import 'storage_service.dart';

class PoemGuidanceResult {
  final String guidance;
  final String responsePoem;

  const PoemGuidanceResult({required this.guidance, required this.responsePoem});
}

class GeminiTextService {
  static const _model = 'gemini-2.5-flash';

  final StorageService _storage = StorageService();

  Future<PoemGuidanceResult> guide(String userText, Persona persona) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No Gemini API key set. Go to Settings and add your key.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are a wise mentor from the ${persona.name} (${persona.englishName}) school of Chinese thought, reviewing a piece of writing (a poem, reflection, or personal ideology) someone has written themselves.
Philosophy and imagery to draw on: ${persona.philosophy}

Detect the language of their writing.
Step 1: Offer warm, thoughtful guidance from this persona's philosophical perspective — what resonates, what could deepen, how this school of thought would approach their theme.
Step 2: Write a short response poem, in the same language as their writing, in this persona's classical style, that answers or elevates what they wrote.

Respond ONLY as raw JSON, no markdown fences, no extra commentary, in exactly this shape:
{"guidance": "...", "responsePoem": "..."}
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
              {'text': userText},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini. Raw: ${response.body}');
    }

    final text = candidates[0]['content']['parts'][0]['text'] as String;
    final parsed = jsonDecode(text) as Map<String, dynamic>;

    return PoemGuidanceResult(
      guidance: parsed['guidance'] as String? ?? '',
      responsePoem: parsed['responsePoem'] as String? ?? '',
    );
  }
}