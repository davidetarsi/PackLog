import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/ai_input/helpers/start_ai_scan.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';

class _RecordingAiImport extends AiImportNotifier {
  _RecordingAiImport([this.initial = const AiImportState()]);

  final AiImportState initial;

  @override
  AiImportState build() => initial;

  List<File>? processedFiles;
  int resetCount = 0;

  void finishProcessing() => state = state.copyWith(isLoading: false);

  @override
  void reset() {
    resetCount++;
    super.reset();
  }

  @override
  Future<void> processFiles(List<File> files) async {
    processedFiles = files;
    state = state.copyWith(isLoading: true, totalImages: files.length);
  }
}

void main() {
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  late _RecordingAiImport aiImport;
  late List<MethodCall> pickerCalls;
  late GoRouter router;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    aiImport = _RecordingAiImport();
    pickerCalls = [];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  TextButton(
                    onPressed: () => startAiScan(context, ref, 'h1'),
                    child: const Text('scan'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Future.wait([
                        startAiScan(context, ref, 'h1'),
                        startAiScan(context, ref, 'h1'),
                      ]);
                    },
                    child: const Text('scan twice'),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/houses/:id/ai-import/results',
          name: 'ai-import-results',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('results ${state.pathParameters['id']}'),
                Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => startAiScan(context, ref, 'h1'),
                    child: const Text('scan from results'),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('other route')),
        ),
      ],
    );
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('it', 'IT'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [aiImportNotifierProvider.overrideWith(() => aiImport)],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
  }

  testWidgets('apre subito Galleria e Fotocamera e prosegue ai risultati', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          pickerCalls.add(call);
          if (call.method == 'pickMultiImage') return ['/tmp/photo.jpg'];
          return null;
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(find.text('results h1'), findsOneWidget);
    expect(pickerCalls.single.method, 'pickMultiImage');
    expect(pickerCalls.single.arguments['limit'], kAiScanMaxPhotos);
    expect(aiImport.state.selectedHouseId, 'h1');
    expect(aiImport.processedFiles?.single.path, '/tmp/photo.jpg');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('usa la fotocamera e passa una sola immagine', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          pickerCalls.add(call);
          return '/tmp/camera.jpg';
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('results h1'), findsOneWidget);
    expect(pickerCalls.single.method, 'pickImage');
    expect(pickerCalls.single.arguments['source'], ImageSource.camera.index);
    expect(aiImport.processedFiles, hasLength(1));
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('limita a cinque anche se il plugin restituisce piu foto', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          pickerCalls.add(call);
          return List.generate(7, (index) => '/tmp/$index.jpg');
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(aiImport.processedFiles, hasLength(kAiScanMaxPhotos));
    expect(aiImport.processedFiles!.last.path, '/tmp/4.jpg');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('annullare il foglio o il picker non resetta lo stato', (
    tester,
  ) async {
    aiImport = _RecordingAiImport(
      const AiImportState(selectedHouseId: 'other-house'),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          pickerCalls.add(call);
          return null;
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(aiImport.resetCount, 0);
    expect(aiImport.state.selectedHouseId, 'other-house');

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.text('results h1'), findsNothing);
    expect(aiImport.resetCount, 0);
    expect(aiImport.state.selectedHouseId, 'other-house');
    expect(pickerCalls, hasLength(1));
  });

  testWidgets('un PlatformException mostra un retry e permette di riprovare', (
    tester,
  ) async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          pickerCalls.add(call);
          attempts++;
          if (attempts == 1) {
            throw PlatformException(code: 'picker_unavailable');
          }
          return ['/tmp/retry.jpg'];
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(find.text('results h1'), findsOneWidget);
    expect(pickerCalls, hasLength(2));
    expect(aiImport.processedFiles?.single.path, '/tmp/retry.jpg');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('un errore di supporto picker mostra retry e non propaga', (
    tester,
  ) async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          attempts++;
          if (attempts == 1) throw StateError('camera unavailable');
          return '/tmp/retry.jpg';
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('results h1'), findsOneWidget);
    expect(aiImport.processedFiles?.single.path, '/tmp/retry.jpg');
    router.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('ignora un secondo avvio mentre il primo foglio e aperto', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('scan twice'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('ignora il retry della SnackBar dopo la dispose della route', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          throw PlatformException(code: 'picker_unavailable');
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    final retry = tester.widget<SnackBarAction>(find.byType(SnackBarAction));

    router.go('/other');
    await tester.pumpAndSettle();
    retry.onPressed();
    await tester.pump();

    expect(find.text('other route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'un router.go fuori dai risultati non blocca le scansioni future',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, (call) async {
            return ['/tmp/photo.jpg'];
          });
      await pumpApp(tester);

      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();
      expect(find.text('results h1'), findsOneWidget);

      router.go('/other');
      await tester.pumpAndSettle();
      aiImport.finishProcessing();
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('non consente un nuovo scan da risultati gia inattivi', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          return ['/tmp/photo.jpg'];
        });
    await pumpApp(tester);

    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    aiImport.finishProcessing();
    await tester.pump();

    await tester.tap(find.text('scan from results'));
    await tester.pumpAndSettle();

    expect(find.text('results h1'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });
}
