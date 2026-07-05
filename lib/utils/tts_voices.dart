/// Curated subset of Gemini's 30 prebuilt TTS voices, labeled thematically
/// to fit this app's philosophical-mentor tone. These are Google's generic
/// named voices (Kore, Charon, etc.) — never a real person's voice.
class TtsVoiceOption {
  final String label;
  final String voiceName;
  const TtsVoiceOption({required this.label, required this.voiceName});
}

const List<TtsVoiceOption> ttsVoiceOptions = [
  TtsVoiceOption(label: 'The Sage (warm, measured)', voiceName: 'Kore'),
  TtsVoiceOption(label: 'The Elder (deep, grounded)', voiceName: 'Charon'),
  TtsVoiceOption(label: 'The Wanderer (bright, clear)', voiceName: 'Puck'),
  TtsVoiceOption(label: 'The Recluse (soft, contemplative)', voiceName: 'Enceladus'),
  TtsVoiceOption(label: 'The Scholar (crisp, formal)', voiceName: 'Orus'),
];

const String defaultTtsVoiceName = 'Kore';