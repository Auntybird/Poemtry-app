class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String personaName;
  final String personaEnglishName;
  final String transcript;
  final String poem;
  final String explanation;
  final String background;
  final String type; // 'voice' or 'written'
  final bool isFavorite;

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.personaName,
    required this.personaEnglishName,
    required this.transcript,
    required this.poem,
    required this.explanation,
    this.background = '',
    this.type = 'voice',
    this.isFavorite = false,
  });

  HistoryEntry copyWith({bool? isFavorite}) => HistoryEntry(
        id: id,
        timestamp: timestamp,
        personaName: personaName,
        personaEnglishName: personaEnglishName,
        transcript: transcript,
        poem: poem,
        explanation: explanation,
        background: background,
        type: type,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'personaName': personaName,
        'personaEnglishName': personaEnglishName,
        'transcript': transcript,
        'poem': poem,
        'explanation': explanation,
        'background': background,
        'type': type,
        'isFavorite': isFavorite,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        personaName: json['personaName'] as String,
        personaEnglishName: json['personaEnglishName'] as String,
        transcript: json['transcript'] as String,
        poem: json['poem'] as String,
        explanation: json['explanation'] as String,
        background: json['background'] as String? ?? '',
        type: json['type'] as String? ?? 'voice',
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
}