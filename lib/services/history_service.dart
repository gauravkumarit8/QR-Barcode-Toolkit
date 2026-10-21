import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';
import 'pro_service.dart';

/// Persists scan/generate history locally (SharedPreferences-backed).
/// No network calls — everything stays on-device, matching the app's
/// offline-first / no-data-collected Play Store Data Safety declaration.
///
/// Every read-modify-write goes through one queue ([_serialized]). Without
/// it, two writes started in the same frame (e.g. several codes captured by
/// batch mode) both read the same list and the last write silently erased
/// the others.
class HistoryService {
  static const _prefsKey = 'history_items_v1';

  /// Bumped after every add/delete/clear so screens (History tab) can refresh
  /// even though they stay alive inside the bottom-nav IndexedStack.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// Free tier item cap — Pro removes this limit.
  /// Favorites count toward the cap but are never dropped by it: only
  /// non-favorites are removed (oldest first).
  static const int freeTierLimit = 50;

  static Future<void> _queue = Future<void>.value();

  /// Runs [action] only after every previously queued action has finished.
  /// A failed action does not block the ones after it.
  static Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Pure add logic (no storage), so it can be unit tested.
  ///
  /// - An existing entry with the same type and value is replaced, so
  ///   scanning the same code again moves it to the top instead of filling
  ///   the list with copies. It keeps its favorite flag.
  /// - Over the free cap, the oldest NON-favorite entries are dropped. The
  ///   entry being added is never dropped.
  @visibleForTesting
  static List<HistoryItem> withAdded(
    List<HistoryItem> existing,
    HistoryItem item, {
    required bool isPro,
    int limit = freeTierLimit,
  }) {
    final list = [...existing];
    var toAdd = item;

    final dup = list.indexWhere((i) => i.type == item.type && i.value == item.value);
    if (dup != -1) {
      toAdd = item.copyWith(favorite: list[dup].favorite);
      list.removeAt(dup);
    }
    list.add(toAdd);

    var excess = list.length - limit;
    if (!isPro && excess > 0) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // oldest first
      final dropIds = <String>{};
      for (final i in list) {
        if (excess == 0) break;
        if (i.favorite || i.id == toAdd.id) continue;
        dropIds.add(i.id);
        excess--;
      }
      list.removeWhere((i) => dropIds.contains(i.id));
    }
    return list;
  }

  Future<List<HistoryItem>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    final out = <HistoryItem>[];
    for (final s in raw) {
      try {
        out.add(HistoryItem.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip one corrupt entry instead of losing the whole history.
      }
    }
    return out;
  }

  Future<void> _write(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      items.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  Future<List<HistoryItem>> getAll() {
    return _serialized(() async {
      final items = await _read();
      // Newest first
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    });
  }

  Future<void> add(HistoryItem item) {
    return _serialized(() async {
      final items = await _read();
      await _write(withAdded(items, item, isPro: ProService.isPro.value));
      changes.value++;
    });
  }

  Future<void> setFavorite(String id, bool favorite) {
    return _serialized(() async {
      final items = await _read();
      final updated = [
        for (final i in items) i.id == id ? i.copyWith(favorite: favorite) : i,
      ];
      await _write(updated);
      changes.value++;
    });
  }

  Future<void> delete(String id) {
    return _serialized(() async {
      final items = await _read();
      await _write(items.where((i) => i.id != id).toList());
      changes.value++;
    });
  }

  Future<void> clear() {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      changes.value++;
    });
  }
}
