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

  test('la stima resta fra 3 e 60 secondi', () async {
    await PackTripTiming.record(const Duration(milliseconds: 100));
    expect(await PackTripTiming.load(), 3000);
    SharedPreferences.setMockInitialValues({});
    await PackTripTiming.record(const Duration(minutes: 5));
    expect(await PackTripTiming.load(), 60000);
  });
}
