class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String personaName;
  final String personaEnglishName;
  final String transcript;
  final String poem;
  final String explanation;

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.personaName,
    required this.personaEnglishName,
    required this.transcript,
    required this.poem,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'personaName': personaName,
        'personaEnglishName': personaEnglishName,
        'transcript': transcript,
        'poem': poem,
        'explanation': explanation,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        personaName: json['personaName'] as String,
        personaEnglishName: json['personaEnglishName'] as String,
        transcript: json['transcript'] as String,
        poem: json['poem'] as String,
        explanation: json['explanation'] as String,
      );
}