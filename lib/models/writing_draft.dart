class WritingDraft {
  final String id; // 💡 Added unique ID for multi-draft support
  final String personaName;
  final String personaEnglishName;
  final String text;
  final String? guidance;
  final String? background;
  final DateTime updatedAt;

  const WritingDraft({
    required this.id,
    required this.personaName,
    required this.personaEnglishName,
    required this.text,
    this.guidance,
    this.background,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'personaName': personaName,
        'personaEnglishName': personaEnglishName,
        'text': text,
        'guidance': guidance,
        'background': background,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WritingDraft.fromJson(Map<String, dynamic> json) => WritingDraft(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        personaName: json['personaName'] as String,
        personaEnglishName: json['personaEnglishName'] as String,
        text: json['text'] as String,
        guidance: json['guidance'] as String?,
        background: json['background'] as String?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}