import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_text_styles.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

void main() {
  test('tre livelli: strong w600, title w700, postcard w800', () {
    const base = TextStyle();
    expect(base.strong.fontWeight, FontWeight.w600);
    expect(base.title.fontWeight, FontWeight.w700);
    expect(base.postcard.fontWeight, FontWeight.w800);
  });

  test('cardTitle: 18 e w600 sul textTheme del tema chiaro', () {
    final card = AppTheme.light.textTheme.cardTitle;
    expect(card, isNotNull);
    expect(card!.fontSize, AppSpacing.fontMd);
    expect(card.fontWeight, FontWeight.w600);
  });
}
