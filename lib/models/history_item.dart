class HistoryItem {
  final String id;
  final String type; // e.g. 'scan' or 'generate'
  final String value;
  final DateTime timestamp;
  final bool favorite;

  HistoryItem({
    required this.id,
    required this.type,
    required this.value,
    required this.timestamp,
    this.favorite = false,
  });

  HistoryItem copyWith({bool? favorite}) => HistoryItem(
        id: id,
        type: type,
        value: value,
        timestamp: timestamp,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'favorite': favorite,
      };

  // 'favorite' defaults to false for items saved before this field existed,
  // so old history entries deserialize cleanly instead of crashing.
  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        type: json['type'] as String,
        value: json['value'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        favorite: json['favorite'] as bool? ?? false,
      );
}
