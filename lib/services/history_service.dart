import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';

/// Persists scan/generate history locally (SharedPreferences-backed).
/// No network calls — everything stays on-device, matching the app's
/// offline-first / no-data-collected Play Store Data Safety declaration.
class HistoryService {
  static const _prefsKey = 'history_items_v1';

  /// Free tier item cap — Pro removes this limit.
  /// TODO: check Pro status (via a future PurchaseService) before enforcing.
  static const int freeTierLimit = 50;

  Future<List<HistoryItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final items = raw
        .map((s) => HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    // Newest first
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<void> add(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    raw.add(jsonEncode(item.toJson()));

    // Enforce free-tier cap by dropping the oldest entries once over limit.
    if (raw.length > freeTierLimit) {
      final items = raw
          .map((s) => HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final trimmed = items.skip(items.length - freeTierLimit).toList();
      await prefs.setStringList(
        _prefsKey,
        trimmed.map((i) => jsonEncode(i.toJson())).toList(),
      );
      return;
    }

    await prefs.setStringList(_prefsKey, raw);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final filtered = raw.where((s) {
      final item = HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
      return item.id != id;
    }).toList();
    await prefs.setStringList(_prefsKey, filtered);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
