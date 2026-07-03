import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/persona.dart';
import 'storage_service.dart';

class WritingGuidance {
  final String guidance;
  final String background;

  const WritingGuidance({required this.guidance, required this.background});
}

class GeminiTextService {
  final StorageService _storage = StorageService();

  Future<WritingGuidance> getGuidance(String userText, Persona persona) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No Gemini API key set. Go to Settings and add your key.');
    }

    // 💡 NEW: Fetch dynamic model and temperature configurations
    final modelName = await _storage.getGeminiModel();
    final temperature = await _storage.getGeminiTemperature();

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$modelName:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are a writing mentor from the ${persona.name} (${persona.englishName}) school of Chinese thought, coaching someone drafting their own poem or reflection.
Philosophy and imagery available to this school: ${persona.philosophy}

Detect the language of their draft.

CRITICAL RULE: Do NOT write the poem for them. Do NOT include any finished poem, verse, or line you composed yourself anywhere in your response. This is a coaching exercise — every line of the final piece must be written by the person themselves.

Step 1 (guidance): Give specific, actionable coaching in 3-5 sentences, in the same language as their draft: what's working, where the imagery or structure could align more closely with this persona's philosophy, and one or two concrete techniques to try. Optionally end with one guiding question. Never supply replacement lines.

Step 2 (background): In 2-4 sentences, same language as their draft, explain: (a) the classical form convention relevant to their language — for Chinese, e.g. Jueju's 4-line/7-character structure and where the rhyme falls; for English, e.g. iambic pentameter or a quatrain's rhyme scheme — and (b) the core tenets and imagery vocabulary of the ${persona.name} school they can draw from. This is reference material only.

Respond ONLY as raw JSON, no markdown fences, no extra commentary, in exactly this shape:
{"guidance": "...", "background": "..."}
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
        // 💡 NEW: Injects temperature directly into the REST API call
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': temperature,
        },
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

    return WritingGuidance(
      guidance: parsed['guidance'] as String? ?? '',
      background: parsed['background'] as String? ?? '',
    );
  }
}