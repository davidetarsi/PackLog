import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Extension del tema per gli stili dei componenti Empty State e Error State.
/// 
/// Definisce tutti gli stili predefiniti per DsEmptyState e DsErrorState,
/// mantenendo la possibilità di override specifici per singolo widget.
/// 
/// Uso:
/// ```dart
/// final theme = context.errorEmptyTheme;
/// Text(title, style: theme.emptyStateTitle);
/// ```
@immutable
class ErrorEmptyThemeExtension extends ThemeExtension<ErrorEmptyThemeExtension> {
  // === Empty State Styles ===
  
  /// Stile del titolo principale negli empty state
  final TextStyle emptyStateTitle;
  
  /// Stile del sottotitolo negli empty state
  final TextStyle emptyStateSubtitle;
  
  /// Dimensione dell'icona negli empty state
  final double emptyStateIconSize;
  
  /// Colore dell'icona negli empty state
  final Color emptyStateIconColor;
  
  /// Colore del testo del titolo negli empty state
  final Color emptyStateTitleColor;
  
  /// Colore del testo del sottotitolo negli empty state
  final Color emptyStateSubtitleColor;
  
  // === Error State Styles ===
  
  /// Stile del messaggio negli error state
  final TextStyle errorStateMessage;
  
  /// Dimensione dell'icona negli error state
  final double errorStateIconSize;
  
  /// Colore dell'icona negli error state
  final Color errorStateIconColor;
  
  /// Label del bottone retry negli error state
  final String errorStateRetryLabel;
  
  // === Spacing ===
  
  /// Spaziatura verticale tra icona e testo
  final double stateSpacingMd;
  
  /// Spaziatura verticale tra testo e azione
  final double stateSpacingLg;
  
  /// Spaziatura verticale tra titolo e sottotitolo
  final double stateSpacingSm;

  const ErrorEmptyThemeExtension({
    required this.emptyStateTitle,
    required this.emptyStateSubtitle,
    required this.emptyStateIconSize,
    required this.emptyStateIconColor,
    required this.emptyStateTitleColor,
    required this.emptyStateSubtitleColor,
    required this.errorStateMessage,
    required this.errorStateIconSize,
    required this.errorStateIconColor,
    required this.errorStateRetryLabel,
    required this.stateSpacingMd,
    required this.stateSpacingLg,
    required this.stateSpacingSm,
  });

  /// Tema predefinito per il dark mode
  static ErrorEmptyThemeExtension get darkDefaults => const ErrorEmptyThemeExtension(
    // Empty State
    emptyStateTitle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.normal,
      color: AppColors.disabled,
    ),
    emptyStateSubtitle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AppColors.disabled,
    ),
    emptyStateIconSize: 80,
    emptyStateIconColor: AppColors.disabled,
    emptyStateTitleColor: AppColors.disabled,
    emptyStateSubtitleColor: AppColors.disabled,
    
    // Error State
    errorStateMessage: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    errorStateIconSize: 80,
    errorStateIconColor: AppColors.destructive,
    errorStateRetryLabel: 'common.retry',
    
    // Spacing
    stateSpacingMd: 16,
    stateSpacingLg: 24,
    stateSpacingSm: 8,
  );

  /// Tema predefinito per il light mode
  static ErrorEmptyThemeExtension get lightDefaults => ErrorEmptyThemeExtension(
    // Empty State
    emptyStateTitle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.normal,
      color: Colors.grey.shade600,
    ),
    emptyStateSubtitle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Colors.grey.shade600,
    ),
    emptyStateIconSize: 80,
    emptyStateIconColor: Colors.grey.shade400,
    emptyStateTitleColor: Colors.grey.shade600,
    emptyStateSubtitleColor: Colors.grey.shade600,
    
    // Error State
    errorStateMessage: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    errorStateIconSize: 80,
    errorStateIconColor: Colors.red.shade700,
    errorStateRetryLabel: 'common.retry',
    
    // Spacing
    stateSpacingMd: 16,
    stateSpacingLg: 24,
    stateSpacingSm: 8,
  );

  @override
  ThemeExtension<ErrorEmptyThemeExtension> copyWith({
    TextStyle? emptyStateTitle,
    TextStyle? emptyStateSubtitle,
    double? emptyStateIconSize,
    Color? emptyStateIconColor,
    Color? emptyStateTitleColor,
    Color? emptyStateSubtitleColor,
    TextStyle? errorStateMessage,
    double? errorStateIconSize,
    Color? errorStateIconColor,
    String? errorStateRetryLabel,
    double? stateSpacingMd,
    double? stateSpacingLg,
    double? stateSpacingSm,
  }) {
    return ErrorEmptyThemeExtension(
      emptyStateTitle: emptyStateTitle ?? this.emptyStateTitle,
      emptyStateSubtitle: emptyStateSubtitle ?? this.emptyStateSubtitle,
      emptyStateIconSize: emptyStateIconSize ?? this.emptyStateIconSize,
      emptyStateIconColor: emptyStateIconColor ?? this.emptyStateIconColor,
      emptyStateTitleColor: emptyStateTitleColor ?? this.emptyStateTitleColor,
      emptyStateSubtitleColor: emptyStateSubtitleColor ?? this.emptyStateSubtitleColor,
      errorStateMessage: errorStateMessage ?? this.errorStateMessage,
      errorStateIconSize: errorStateIconSize ?? this.errorStateIconSize,
      errorStateIconColor: errorStateIconColor ?? this.errorStateIconColor,
      errorStateRetryLabel: errorStateRetryLabel ?? this.errorStateRetryLabel,
      stateSpacingMd: stateSpacingMd ?? this.stateSpacingMd,
      stateSpacingLg: stateSpacingLg ?? this.stateSpacingLg,
      stateSpacingSm: stateSpacingSm ?? this.stateSpacingSm,
    );
  }

  @override
  ThemeExtension<ErrorEmptyThemeExtension> lerp(
    covariant ThemeExtension<ErrorEmptyThemeExtension>? other,
    double t,
  ) {
    if (other is! ErrorEmptyThemeExtension) return this;
    
    return ErrorEmptyThemeExtension(
      emptyStateTitle: TextStyle.lerp(emptyStateTitle, other.emptyStateTitle, t) ?? emptyStateTitle,
      emptyStateSubtitle: TextStyle.lerp(emptyStateSubtitle, other.emptyStateSubtitle, t) ?? emptyStateSubtitle,
      emptyStateIconSize: lerpDouble(emptyStateIconSize, other.emptyStateIconSize, t),
      emptyStateIconColor: Color.lerp(emptyStateIconColor, other.emptyStateIconColor, t) ?? emptyStateIconColor,
      emptyStateTitleColor: Color.lerp(emptyStateTitleColor, other.emptyStateTitleColor, t) ?? emptyStateTitleColor,
      emptyStateSubtitleColor: Color.lerp(emptyStateSubtitleColor, other.emptyStateSubtitleColor, t) ?? emptyStateSubtitleColor,
      errorStateMessage: TextStyle.lerp(errorStateMessage, other.errorStateMessage, t) ?? errorStateMessage,
      errorStateIconSize: lerpDouble(errorStateIconSize, other.errorStateIconSize, t),
      errorStateIconColor: Color.lerp(errorStateIconColor, other.errorStateIconColor, t) ?? errorStateIconColor,
      errorStateRetryLabel: other.errorStateRetryLabel,
      stateSpacingMd: lerpDouble(stateSpacingMd, other.stateSpacingMd, t),
      stateSpacingLg: lerpDouble(stateSpacingLg, other.stateSpacingLg, t),
      stateSpacingSm: lerpDouble(stateSpacingSm, other.stateSpacingSm, t),
    );
  }
}

/// Helper per interpolare double values
double lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) return 0.0;
  final aValue = a ?? b ?? 0.0;
  final bValue = b ?? a ?? 0.0;
  return aValue + (bValue - aValue) * t;
}

/// Extension per accedere facilmente agli stili Empty/Error State dal context
extension ErrorEmptyThemeExtensionX on BuildContext {
  ErrorEmptyThemeExtension get errorEmptyTheme =>
      Theme.of(this).extension<ErrorEmptyThemeExtension>()!;
}
