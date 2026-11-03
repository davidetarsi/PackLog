import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/services/pack_trip_timing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('senza storia vale il tempo di partenza', () async {
    expect(await PackTripTiming.load(), kDefaultPackTripMs);
    expect(kDefaultPackTripMs, 10000);
  });

  test('la media è semplice sulle ultime generazioni riuscite', () async {
    await PackTripTiming.record(const Duration(seconds: 8));
    expect(await PackTripTiming.load(), 8000);
    await PackTripTiming.record(const Duration(seconds: 12));
    expect(await PackTripTiming.load(), 10000);
  });

  test('ricorda solo le ultime cinque', () async {
    for (final s in [30, 10, 10, 10, 10, 10]) {
      await PackTripTiming.record(Duration(seconds: s));
    }
    expect(await PackTripTiming.load(), 10000);
  });

  test('un campione fuori misura pesa al massimo quanto il limite', () async {
    for (var i = 0; i < 4; i++) {
      await PackTripTiming.record(const Duration(seconds: 10));
    }
    await PackTripTiming.record(const Duration(minutes: 5));
    // Campione portato a 60 s: la media sale di (60 - 10) / 5 = 10 s al massimo.
    expect(await PackTripTiming.load(), 20000);
  });

  test('un campione troppo breve vale 3 secondi', () async {
    await PackTripTiming.record(const Duration(milliseconds: 100));
    expect(await PackTripTiming.load(), 3000);
  });
}
