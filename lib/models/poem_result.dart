class PoemResult {
  final String personaName;
  final String personaEnglishName;
  final String transcript;
  final String poem;
  final String explanation;
  final String background;

  const PoemResult({
    required this.personaName,
    required this.personaEnglishName,
    required this.transcript,
    required this.poem,
    required this.explanation,
    this.background = '',
  });
}