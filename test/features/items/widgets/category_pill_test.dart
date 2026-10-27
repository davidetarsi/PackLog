import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

void main() {
  testWidgets('pillole categoria su 320 con testo a 2.0: niente overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: AppConstants.categoryRowHeight,
              child: Row(
                children: [
                  for (final category in ItemCategory.values) ...[
                    if (category != ItemCategory.values.first)
                      const SizedBox(width: 4),
                    Expanded(
                      child: CategoryPill(
                        category: category,
                        pillState: CategoryPillState.forced,
                        onTap: () {},
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byType(CategoryPill),
      findsNWidgets(ItemCategory.values.length),
    );
  });
}
