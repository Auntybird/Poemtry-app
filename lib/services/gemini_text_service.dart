import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/persona.dart';
import '../utils/gemini_rate_limit.dart';
import 'storage_service.dart';

class WritingGuidance {
  final String guidance;
  final String background;

  const WritingGuidance({required this.guidance, required this.background});
}

class PoemAnalysis {
  final String structureType;
  final String tonalFeedback;
  final String rhymeFeedback;
  final List<String> ruleBreaks;

  const PoemAnalysis({
    required this.structureType,
    required this.tonalFeedback,
    required this.rhymeFeedback,
    required this.ruleBreaks,
  });
}

class GeminiTextService {
  static const List<String> supportedModels = [
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  final StorageService _storage = StorageService();

  static List<String> resolveModelCandidates(String? preferredModel) {
    final trimmed = preferredModel?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return supportedModels.toList();
    }

    final ordered = <String>[trimmed];
    for (final model in supportedModels) {
      if (model != trimmed && !ordered.contains(model)) {
        ordered.add(model);
      }
    }
    return ordered;
  }

  Future<String> _generateWithFallback({
    required String systemPrompt,
    required double temperature,
    required String userText,
  }) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'No Gemini API key set. Go to Settings and add your key.');
    }

    final modelNames = resolveModelCandidates(await _storage.getGeminiModel());
    Object? lastError;
    String? lastRateLimitBody;

    for (final modelName in modelNames) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$apiKey',
        );

        final response = await http.post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text': '$systemPrompt\n\nUser request:\n$userText',
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': temperature,
            },
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (text is String && text.isNotEmpty) {
            return text;
          }
          throw Exception('No response from Gemini.');
        }

        final errorBody = response.body;
        lastError = 'Model $modelName failed (${response.statusCode}): $errorBody';
        if (response.statusCode == 429) {
          lastRateLimitBody = errorBody;
        }

        // Retry with the next candidate model on: bad request/model-not-found
        // (400/404/422) OR rate-limit/quota exhaustion (429). Without 429 here,
        // a quota hit on the first model never falls back to the lite model and
        // just surfaces as "quota exceeded" even though a usable fallback model
        // remains untried.
        if (response.statusCode == 400 ||
            response.statusCode == 404 ||
            response.statusCode == 422 ||
            response.statusCode == 429) {
          if (modelName != modelNames.last) {
            continue;
          }
        }

        break;
      } catch (e) {
        lastError = e;
        if (modelName == modelNames.last) {
          break;
        }
      }
    }

    if (lastRateLimitBody != null) {
      throw Exception(formatRateLimitMessage(parseRateLimitInfo(lastRateLimitBody)));
    }
    throw Exception('Gemini request failed: $lastError');
  }

  Future<WritingGuidance> getGuidance(String userText, Persona persona) async {
    final temperature = await _storage.getGeminiTemperature();

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

    final responseText = await _generateWithFallback(
      systemPrompt: systemPrompt,
      temperature: temperature,
      userText: userText,
    );
    final parsed = _parseJsonResponse(responseText);

    return WritingGuidance(
      guidance: parsed['guidance'] as String? ?? '',
      background: parsed['background'] as String? ?? '',
    );
  }

  Future<PoemAnalysis> analyzeStructure(String userText) async {
    const double analyticalTemperature = 0.1;

    const systemPrompt = '''
You are a strict master of classical Chinese poetry form and structure (Gushi, Jueju, Lushi) and traditional English meter (Sonnets, Quatrains, Iambic Pentameter).
Analyze the provided poem strictly for its structural integrity. Do NOT provide creative coaching.

Step 1: Identify the intended classical form based on character/syllable count and line count. If it is modern free verse, state that.
Step 2: Analyze the Tonal Pattern (Ping Ze / 平仄) for Chinese, or the meter for English. Does it follow traditional rules?
Step 3: Analyze the Rhyme Scheme (Yayun / 押韵). Identify the rhyme category and check for any dropped rhymes.
Step 4: List any specific characters or lines that violate the tonal or rhyming rules as an array of strings. If none, return an empty array.

Respond ONLY as raw JSON, no markdown fences, no extra commentary, in exactly this shape:
{
  "structureType": "e.g., Qiyan Jueju (Seven-character Quatrain)",
  "tonalFeedback": "Detailed analysis of Ping Ze or meter...",
  "rhymeFeedback": "Detailed analysis of the rhyme scheme...",
  "ruleBreaks": ["Line 2: '风' breaks the Ping Ze rule", "Line 4: '月' does not rhyme"]
}
''';

    final responseText = await _generateWithFallback(
      systemPrompt: systemPrompt,
      temperature: analyticalTemperature,
      userText: userText,
    );
    final parsed = _parseJsonResponse(responseText);

    return PoemAnalysis(
      structureType: parsed['structureType'] as String? ?? 'Unknown Form',
      tonalFeedback: parsed['tonalFeedback'] as String? ?? '',
      rhymeFeedback: parsed['rhymeFeedback'] as String? ?? '',
      ruleBreaks: List<String>.from(parsed['ruleBreaks'] ?? []),
    );
  }

  Map<String, dynamic> _parseJsonResponse(String responseText) {
    if (responseText.isEmpty) {
      throw Exception('No response from Gemini.');
    }
    return jsonDecode(responseText) as Map<String, dynamic>;
  }
}