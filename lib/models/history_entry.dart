class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String personaName;
  final String personaEnglishName;
  final String transcript;
  final String poem;
  final String explanation;
  final String background;
  final String type;
  final bool isFavorite;
  final String? imageUrl; // 🌟 New field

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
    this.imageUrl, // 🌟 Updated
  });

  HistoryEntry copyWith({bool? isFavorite, String? imageUrl}) => HistoryEntry(
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
        imageUrl: imageUrl ?? this.imageUrl, // 🌟 Updated
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
        'imageUrl': imageUrl, // 🌟 Updated
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
        imageUrl: json['imageUrl'] as String?, // 🌟 Updated
      );
}