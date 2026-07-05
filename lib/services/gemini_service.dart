import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/persona.dart';
import '../models/poem_result.dart';
import '../utils/gemini_rate_limit.dart';
import 'storage_service.dart';

class GeminiPoemService {
  static const List<String> _supportedModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];

  final StorageService _storage = StorageService();

  Future<String> _resolveModelName(String? preferredModel) async {
    final trimmed = preferredModel?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return StorageService.defaultModel;
    }

    if (_supportedModels.contains(trimmed)) {
      return trimmed;
    }
    return StorageService.defaultModel;
  }

  // --- Daily Prompts Generation ---
  
  Future<List<String>> fetchWeeklyPrompts(String personaName, String philosophyDescription) async {
    final cachedPrompts = await _storage.getCachedWeeklyPrompts(personaName);
    if (cachedPrompts != null && cachedPrompts.isNotEmpty) {
      return cachedPrompts;
    }

    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No Gemini API key set. Go to Settings and add your key.');
    }

    final modelName = await _resolveModelName(await _storage.getGeminiModel());
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are $personaName, a master mentor of the $philosophyDescription school of Chinese philosophy.
Generate a list of exactly 7 unique, highly evocative creative writing prompts or daily inspirations for a user looking to reflect or write a poem.
Each prompt should encourage mindfulness, observation of nature, or emotional self-reflection matching your philosophical view.
Keep each prompt short (1-2 sentences).
Format your output EXACTLY like this with no numbers, bullet points, or introductory text, separating each prompt with '|||':
Prompt one here|||Prompt two here|||Prompt three here
''';

    try {
      final response = await http.post(
        uri,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': systemPrompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
          },
        }),
      );

      if (response.statusCode == 429) {
        throw Exception('Rate Limit');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String textResult = data['candidates'][0]['content']['parts'][0]['text'];
        
        List<String> prompts = textResult
            .split('|||')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (prompts.isEmpty) throw Exception("Malformed AI response");
        
        await _storage.saveWeeklyPrompts(personaName, prompts);
        return prompts;
      } else {
        throw Exception("Failed to contact Gemini: ${response.statusCode}");
      }
    } catch (e) {
      // Fallback prompts if absolutely everything fails
      return [
        "Look closely at the space between things. What fills the emptiness?",
        "Write of a river that changes direction, yet remains the same river.",
        "Reflect on a silent burden you carry. Give it a shape and color.",
        "The wind leaves no trace on the mountain. Write about an impact left unseen.",
        "Capture the transition of twilight into complete darkness.",
        "A single leaf falls without a sound. What does it whisper to the earth?",
        "Consider an old friend who has drifted away. Send them a verse."
      ];
    }
  }

  // --- Audio-to-Poem ---

  Future<PoemResult> generateFromAudio(String audioFilePath) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('No Gemini API key set. Go to Settings and add your key.');
    }

    final savedModel = await _storage.getGeminiModel();
    final targetModel = await _resolveModelName(savedModel);
    final persona = personas[Random().nextInt(personas.length)];

    try {
      // Attempt generation with preferred model
      return await _executeAudioRequest(audioFilePath, persona, apiKey, targetModel);
    } catch (e) {
      // 🌟 SMART FALLBACK: If rate limited and we aren't already using lite, try lite.
      if (e is GeminiRateLimitException && targetModel != 'gemini-2.5-flash-lite') {
        try {
          return await _executeAudioRequest(audioFilePath, persona, apiKey, 'gemini-2.5-flash-lite');
        } catch (fallbackError) {
          // Prefer info from whichever error actually carries a parseable body.
          final infoSource = fallbackError is GeminiRateLimitException
              ? fallbackError.responseBody
              : e.responseBody;
          throw Exception(formatRateLimitMessage(parseRateLimitInfo(infoSource)));
        }
      } else if (e is GeminiRateLimitException) {
        throw Exception(formatRateLimitMessage(parseRateLimitInfo(e.responseBody)));
      }
      rethrow;
    }
  }

  Future<PoemResult> _executeAudioRequest(String audioFilePath, Persona persona, String apiKey, String modelName) async {
    final bytes = await File(audioFilePath).readAsBytes();
    final base64Audio = base64Encode(bytes);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/$modelName:generateContent?key=$apiKey',
    );

    final systemPrompt = '''
You are a master poet channeling the ${persona.name} (${persona.englishName}) school of Chinese thought.
Philosophy and imagery to draw on: ${persona.philosophy}

Step 1: Transcribe what the speaker says in the audio, in its original language.
Step 2: Detect the language of the transcript.
Step 3: Write a poem suited to their situation, strictly in that persona's philosophy and voice.
  - If Chinese: a classical Jueju (绝句) or Ci (词) with proper rhyme, plus a modern-Chinese explanation of the poem's meaning and how it reflects this persona's philosophy.
  - If English: a classical English quatrain or short sonnet (iambic meter), plus a modern-English explanation of the poem's meaning and how it reflects this persona's philosophy.
Step 4: Write a short "background" note (2-4 sentences, same language as the transcript) stating: the classical form used and its convention (e.g. rhyme scheme, line/character count), and the core philosophical tenets of the ${persona.name} school that this poem draws from.

Respond ONLY with raw JSON, no markdown fences, no extra commentary, in exactly this shape:
{"transcript": "...", "poem": "...", "explanation": "...", "background": "..."}
''';

    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': systemPrompt,
              },
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
          'temperature': 0.7,
        },
      }),
    );

    if (response.statusCode == 429) {
      throw GeminiRateLimitException(response.body);
    } else if (response.statusCode != 200) {
      throw Exception('The winds of inspiration failed us (Error ${response.statusCode}). Please try again later.');
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('The AI responded with silence. Please try again.');
    }

    final text = candidates[0]['content']['parts'][0]['text'] as String;
    
    // Clean up markdown block if Gemini accidentally wraps it
    final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(cleanText) as Map<String, dynamic>;

    return PoemResult(
      personaName: persona.name,
      personaEnglishName: persona.englishName,
      transcript: parsed['transcript'] as String? ?? '',
      poem: parsed['poem'] as String? ?? '',
      explanation: parsed['explanation'] as String? ?? '',
      background: parsed['background'] as String? ?? '',
    );
  }
}