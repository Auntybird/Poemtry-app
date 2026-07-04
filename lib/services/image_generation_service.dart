import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class ImageGenerationService {
  final StorageService _storage = StorageService();

  Future<String?> generateShanshuiPainting(String poemText) async {
    final apiKey = await _storage.getApiKey();
    if (apiKey == null) return null;

    // 1. Generate prompt via Gemini (using your existing Gemini service logic)
    // For simplicity, we create a direct prompt here
    final prompt = "Traditional Chinese ink-wash painting (Shanshui) of the following poem, emphasizing negative space and misty atmosphere: $poemText";

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/images/generations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "dall-e-3",
        "prompt": prompt,
        "n": 1,
        "size": "1024x1024",
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'][0]['url'];
    }
    return null;
  }
}