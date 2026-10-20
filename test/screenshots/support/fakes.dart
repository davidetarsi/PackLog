import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pack_log/features/ai_input/model/ai_failure_reason.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/trips/model/trip_weather.dart';
import 'package:pack_log/features/trips/services/trip_weather_service.dart';

import 'seed.dart';

/// Import AI pilotato dal test: niente fotocamera, niente GPT.
///
/// Parte da [_initial] e passa a uno stato nuovo con [emit]. La schermata
/// risultati inizializza i campi di testo sia dallo stato già disponibile al
/// mount sia dalle successive transizioni di stato.
class FakeAiImport extends AiImportNotifier {
  FakeAiImport([this._initial = const AiImportState(isLoading: true)]);

  final AiImportState _initial;

  @override
  AiImportState build() => _initial;

  void emit(AiImportState next) => state = next;

  @override
  Future<void> processFiles(List<File> files) async {}

  @override
  Future<void> retryFailed() async {}
}

/// Meteo senza rete: numeri fissi per luogo, previsione entro 14 giorni dalla
/// fine della tappa e media di 5 anni oltre, come la funzione vera.
class FakeTripWeather extends TripWeatherService {
  static const _table = {
    // nome: (minima, massima, quota di giorni di pioggia, vento max)
    'Lisbona': (15.0, 22.0, 0.2, 28.0),
    'Sintra': (13.0, 19.0, 0.67, 46.0),
    'Firenze': (14.0, 24.0, 0.0, 18.0),
    'Casa al mare': (17.0, 25.0, 0.0, 22.0),
  };

  @override
  Future<TripWeather> fetch(TripWeatherRequest request) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return TripWeather(
      signature: request.signature,
      // Un orario fisso: lo screenshot non cambia da un'esecuzione all'altra.
      fetchedAt: today.add(const Duration(hours: 9, minutes: 30)),
      stops: [
        for (final stop in request.stops)
          _stop(stop, forecast: stop.to.difference(today).inDays <= 14),
      ],
    );
  }

  StopWeather _stop(WeatherStopRequest stop, {required bool forecast}) {
    final (min, max, rainShare, wind) =
        _table[stop.name] ?? (12.0, 20.0, 0.3, 20.0);
    return StopWeather(
      name: stop.name,
      from: stop.from,
      to: stop.to,
      source: forecast ? WeatherSource.forecast : WeatherSource.climate,
      years: forecast ? null : 5,
      tempMin: min,
      tempMax: max,
      rainDays: rainShare * stop.days,
      rainMm: rainShare * stop.days * 4,
      windMaxKmh: wind,
      uvMax: 6,
    );
  }
}

/// Meteo con il tetto giornaliero finito.
class FakeTripWeatherCapReached extends TripWeatherService {
  @override
  Future<TripWeather> fetch(TripWeatherRequest request) async =>
      throw const TripWeatherCapException();
}

const _fixturesDir = 'build/ui-screenshots-fixtures';

/// "Foto" dei capi: rettangoli colorati generati al volo. Non c'è una
/// fotocamera nei test e non vogliamo immagini personali nel repo.
late File photoShirt;
late File photoJeans;

Future<void> createPhotoFixtures() async {
  photoShirt = await _photo('shirt.png', const Color(0xFF8FB8DE));
  photoJeans = await _photo('jeans.png', const Color(0xFF3B5B85));
}

Future<File> _photo(String name, Color garment) async {
  const size = Size(600, 600);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9E4DA));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(150, 120, 300, 380),
      const Radius.circular(40),
    ),
    Paint()..color = garment,
  );
  final image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_fixturesDir/$name')..createSync(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

ClothingAnalysisResult _garment(String name, String color, String sub) =>
    ClothingAnalysisResult(
      name: name,
      category: sub == 'Pantaloni' ? 'Lower Body' : 'Upper Body',
      subCategory: sub,
      baseColor: color,
      pattern: 'Tinta unita',
      coverage: 'Busto',
      fit: 'Regular',
      warmth: 2,
      formality: 'Casual',
      activityTags: const ['città', 'viaggio'],
    );

AiImportState aiResultsState({String? houseId = kHomeId}) => AiImportState(
  selectedHouseId: houseId,
  photoGroups: [
    PhotoGroup(
      photo: photoShirt,
      results: [
        _garment('Camicia di lino azzurra', 'Azzurro', 'Camicia'),
        _garment('T-shirt bianca', 'Bianco', 'T-shirt'),
      ],
    ),
    PhotoGroup(
      photo: photoJeans,
      results: [_garment('Jeans slim blu scuro', 'Blu', 'Pantaloni')],
    ),
  ],
);

AiImportState aiLoadingState() =>
    const AiImportState(isLoading: true, processingIndex: 2, totalImages: 3);

AiImportState aiFailureState(AiFailureReason reason) =>
    AiImportState(failureReason: reason);

AiImportState aiPartialFailureState() =>
    aiResultsState().copyWith(failureReason: AiFailureReason.network);
