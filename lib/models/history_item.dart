class HistoryItem {
  final String id;
  final String type; // e.g. 'scan' or 'generate'
  final String value;
  final DateTime timestamp;

  HistoryItem({
    required this.id,
    required this.type,
    required this.value,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        type: json['type'] as String,
        value: json['value'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
