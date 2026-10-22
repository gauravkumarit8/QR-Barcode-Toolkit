import 'package:flutter_test/flutter_test.dart';
import 'package:qr_barcode_toolkit/utils/review_policy.dart';

void main() {
  final now = DateTime(2026, 11, 1).millisecondsSinceEpoch;
  int daysAgo(int d) => now - Duration(days: d).inMilliseconds;

  bool ask({
    int actions = 4,
    int launches = 3,
    int askedCount = 0,
    int? lastAskedMs,
  }) =>
      ReviewPolicy.shouldAsk(
        actions: actions,
        launches: launches,
        askedCount: askedCount,
        lastAskedMs: lastAskedMs,
        nowMs: now,
      );

  test('asks once the user has done enough and opened the app enough', () {
    expect(ask(), isTrue);
    expect(ask(actions: 10, launches: 20), isTrue);
  });

  test('not before enough useful actions', () {
    expect(ask(actions: ReviewPolicy.minActions - 1), isFalse);
    expect(ask(actions: 0), isFalse);
  });

  test('not in the first launches', () {
    expect(ask(launches: ReviewPolicy.minLaunches - 1), isFalse);
    expect(ask(launches: 1), isFalse);
  });

  test('never more than the maximum number of times', () {
    expect(ask(askedCount: ReviewPolicy.maxAsks - 1), isTrue);
    expect(ask(askedCount: ReviewPolicy.maxAsks), isFalse);
  });

  test('waits at least 60 days between asks', () {
    expect(ask(askedCount: 1, lastAskedMs: daysAgo(59)), isFalse);
    expect(ask(askedCount: 1, lastAskedMs: daysAgo(60)), isTrue);
    expect(ask(askedCount: 1, lastAskedMs: daysAgo(200)), isTrue);
  });

  test('a first ask has no waiting period', () {
    expect(ask(askedCount: 0, lastAskedMs: null), isTrue);
  });
}
