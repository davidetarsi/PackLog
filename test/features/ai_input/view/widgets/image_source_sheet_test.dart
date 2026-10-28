import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pack_log/features/ai_input/view/widgets/image_source_sheet.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

/// Apre il sheet e restituisce un getter del risultato (letto dopo il tap).
Future<ImageSource? Function()> _openSheet(
  WidgetTester tester, {
  String? gallerySubtitle,
  String? cameraSubtitle,
}) async {
  ImageSource? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showImageSourceSheet(
                context,
                gallerySubtitle: gallerySubtitle,
                cameraSubtitle: cameraSubtitle,
              );
            },
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('restituisce la fotocamera quando la si tocca', (tester) async {
    final result = await _openSheet(tester);

    expect(find.byType(DsSheetHeader), findsOneWidget);
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();

    expect(result(), ImageSource.camera);
  });

  testWidgets('restituisce la galleria e mostra i sottotitoli passati', (
    tester,
  ) async {
    final result = await _openSheet(
      tester,
      gallerySubtitle: 'fino a 3',
      cameraSubtitle: 'una foto',
    );

    expect(find.text('fino a 3'), findsOneWidget);
    expect(find.text('una foto'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();

    expect(result(), ImageSource.gallery);
  });

  testWidgets('senza sottotitoli non ne mostra', (tester) async {
    await _openSheet(tester);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
    expect(tiles, hasLength(2));
    expect(tiles.every((t) => t.subtitle == null), isTrue);
  });
}
