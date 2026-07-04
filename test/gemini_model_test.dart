import 'package:flutter_test/flutter_test.dart';
import 'package:poem_app/services/gemini_text_service.dart';

void main() {
  test('prefers the stored model but falls back to supported Gemini models',
      () {
    final candidates =
        GeminiTextService.resolveModelCandidates('gemini-1.5-flash');

    expect(candidates.first, 'gemini-1.5-flash');
    expect(candidates, contains('gemini-2.0-flash'));
    expect(candidates, contains('gemini-2.0-flash-lite'));
  });

  test('uses a safe default model when no model is stored', () {
    final candidates = GeminiTextService.resolveModelCandidates(null);

    expect(candidates.first, 'gemini-2.0-flash');
  });
}
