import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/models/history_item.dart';
import 'package:qr_barcode_toolkit/services/history_service.dart';
import 'package:qr_barcode_toolkit/services/pro_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _base = DateTime(2026, 1, 1);

HistoryItem _item(
  String id,
  String value,
  int minute, {
  String type = 'scan',
  bool favorite = false,
}) =>
    HistoryItem(
      id: id,
      type: type,
      value: value,
      timestamp: _base.add(Duration(minutes: minute)),
      favorite: favorite,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryService.withAdded (pure logic)', () {
    test('adds a new item', () {
      final out = HistoryService.withAdded([], _item('a', 'one', 0), isPro: false);
      expect(out.map((i) => i.id), ['a']);
    });

    test('same type and value replaces the old entry and keeps its favorite flag', () {
      final existing = [_item('old', 'same', 0, favorite: true), _item('x', 'other', 1)];
      final out = HistoryService.withAdded(
        existing,
        _item('new', 'same', 5),
        isPro: false,
      );
      expect(out.where((i) => i.value == 'same').length, 1);
      final kept = out.firstWhere((i) => i.value == 'same');
      expect(kept.id, 'new');
      expect(kept.favorite, isTrue);
      expect(kept.timestamp, _base.add(const Duration(minutes: 5)));
    });

    test('same value but different type is NOT treated as a duplicate', () {
      final existing = [_item('s', 'same', 0, type: 'scan')];
      final out = HistoryService.withAdded(
        existing,
        _item('g', 'same', 1, type: 'generate'),
        isPro: false,
      );
      expect(out.length, 2);
    });

    test('over the cap drops the oldest non-favorite, never a favorite', () {
      final existing = [
        _item('A', 'a', 0, favorite: true), // oldest, but a favorite
        _item('B', 'b', 1),
        _item('C', 'c', 2),
      ];
      final out = HistoryService.withAdded(
        existing,
        _item('D', 'd', 3),
        isPro: false,
        limit: 3,
      );
      expect(out.map((i) => i.id).toSet(), {'A', 'C', 'D'});
    });

    test('the item being added is never dropped, even if everything else is a favorite', () {
      final existing = [
        _item('A', 'a', 0, favorite: true),
        _item('B', 'b', 1, favorite: true),
        _item('C', 'c', 2, favorite: true),
      ];
      final out = HistoryService.withAdded(
        existing,
        _item('D', 'd', 3),
        isPro: false,
        limit: 3,
      );
      expect(out.map((i) => i.id).toSet(), {'A', 'B', 'C', 'D'});
    });

    test('Pro users are not capped', () {
      var list = <HistoryItem>[];
      for (var i = 0; i < 60; i++) {
        list = HistoryService.withAdded(list, _item('id$i', 'v$i', i), isPro: true);
      }
      expect(list.length, 60);
    });
  });

  group('HistoryService (storage)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ProService.isPro.value = false;
    });

    test('many adds started at the same time are all kept (no lost writes)', () async {
      final service = HistoryService();
      await Future.wait([
        for (var i = 0; i < 30; i++) service.add(_item('id$i', 'code$i', i)),
      ]);
      final all = await service.getAll();
      expect(all.length, 30);
    });

    test('getAll returns newest first', () async {
      final service = HistoryService();
      await service.add(_item('old', 'a', 0));
      await service.add(_item('new', 'b', 10));
      final all = await service.getAll();
      expect(all.map((i) => i.id), ['new', 'old']);
    });

    test('favorite survives the free cap through the real add path', () async {
      final service = HistoryService();
      await service.add(_item('fav', 'favorite-value', 0, favorite: true));
      for (var i = 1; i <= HistoryService.freeTierLimit + 5; i++) {
        await service.add(_item('id$i', 'v$i', i));
      }
      final all = await service.getAll();
      expect(all.any((i) => i.id == 'fav'), isTrue);
      expect(all.length, HistoryService.freeTierLimit);
    });

    test('setFavorite and delete persist', () async {
      final service = HistoryService();
      await service.add(_item('a', 'a', 0));
      await service.add(_item('b', 'b', 1));
      await service.setFavorite('a', true);
      await service.delete('b');
      final all = await service.getAll();
      expect(all.length, 1);
      expect(all.single.id, 'a');
      expect(all.single.favorite, isTrue);
    });

    test('clear empties the history', () async {
      final service = HistoryService();
      await service.add(_item('a', 'a', 0));
      await service.clear();
      expect(await service.getAll(), isEmpty);
    });
  });
}
