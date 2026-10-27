import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_opacity.dart';
import 'app_spacing.dart';
import 'error_empty_theme_extension.dart';
import '../constants/app_constants.dart';

/// Tema principale dell'app — Material 3, colori esplicitamente calibrati.
///
/// Principi DS (Fase 2):
/// - Nessun alpha generato a runtime per testo muted: usa onSurfaceVariant.
/// - Nessun alpha su bordi: usa outline / outlineVariant nativi.
/// - tertiary = stati transienti (es. "in viaggio"). Ambra in entrambi i temi.
/// - State layer alpha: 0.08 (hover) / 0.12 (selected) / 0.16 (dragged).
class AppTheme {
  /// Tema chiaro — arancione brand su superfici grigie neutre.
  ///
  /// Il colore sta solo dove ha un significato (brand, avvisi): superfici,
  /// testi e testo sui bottoni pieni non hanno tinta, così il tema non tira
  /// verso il panna o il marrone.
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      // ── Primary ───────────────────────────────────────────────────────────
      // #F4801F: arancione chiaro e spostato verso il giallo, che sul fondo
      // chiaro non legge come rosso.
      //
      // onPrimary quasi nero neutro: il bianco su questo arancione non arriva
      // ad AA (4,5:1), il quasi nero sta a 6,7:1.
      primary: Color(0xFFF4801F),
      onPrimary: Color(0xFF18181B),
      primaryContainer: Color(0xFFFFF3EA),
      // Arancio scuro e non marrone: 4,7:1 sul contenitore.
      onPrimaryContainer: Color(0xFFC2410C),
      // ── Secondary ─────────────────────────────────────────────────────────
      // Grigio neutro per azioni secondarie, distinto dal brand orange.
      secondary: Color(0xFF6B7280),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE5E7EB),
      onSecondaryContainer: Color(0xFF1F2937),
      // ── Tertiary: stati transienti ("in viaggio") ──────────────────────────
      // Ambra brunita. Distinta da primary (arancione) e da itemTemporary (blu).
      tertiary: Color(0xFFD97706),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFEF3C7),
      onTertiaryContainer: Color(0xFF451A03),
      // ── Superfici (grigio neutro, appena freddo) ──────────────────────────
      surface: Color(0xFFF7F7F8),
      onSurface: Color(0xFF18181B),
      // onSurfaceVariant calibrato per leggibilità secondaria WCAG AA in light.
      onSurfaceVariant: Color(0xFF52525B),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF5F5F6),
      surfaceContainer: Color(0xFFF4F4F5),
      surfaceContainerHigh: Color(0xFFE4E4E7),
      surfaceContainerHighest: Color(0xFFD4D4D8),
      // ── Bordi ─────────────────────────────────────────────────────────────
      // outline: bordo forte (selezionato, focus). outlineVariant: divider/card.
      outline: Color(0xFFA1A1AA),
      outlineVariant: Color(0xFFE4E4E7),
      // ── Error / Inverse ───────────────────────────────────────────────────
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      // Container d'errore per avvisi (box di errore parziale): rosa tenue con
      // testo scuro. Senza, Flutter usa `error` pieno e il box diventa un
      // blocco rosso.
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
      inverseSurface: Color(0xFF2D2D2D),
      onInverseSurface: Color(0xFFF5F5F5),
      inversePrimary: Color(0xFFFFAB73),
    );

    return _buildTheme(colorScheme, AppColorsExtension.light);
  }

  /// Tema scuro — arancione luminoso su sfondo dark.
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      // ── Primary ───────────────────────────────────────────────────────────
      // #FF8A50: arancione brand dark (più luminoso per contrasto su dark BG).
      primary: Color(0xFFFF8A50),
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF6B2A00),
      onPrimaryContainer: Color(0xFFFFD9C2),
      // ── Secondary ─────────────────────────────────────────────────────────
      secondary: Color(0xFFA1A1AA),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF3F3F46),
      onSecondaryContainer: Color(0xFFE4E4E7),
      // ── Tertiary: stati transienti ("in viaggio") ──────────────────────────
      // Ambra luminosa per contrasto su dark surface.
      tertiary: Color(0xFFFBBF24),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF451A03),
      onTertiaryContainer: Color(0xFFFEF3C7),
      // ── Superfici (dark) ──────────────────────────────────────────────────
      surface: Color(0xFF1A1A1A),
      onSurface: Color(0xFFF5F5F5),
      // onSurfaceVariant calibrato per dark: bianco abbassato, non alpha grezzo.
      onSurfaceVariant: Color(0xFFB8B8B8),
      surfaceContainerLowest: Color(0xFF0D0D0D),
      surfaceContainerLow: Color(0xFF151515),
      surfaceContainer: Color(0xFF252525),
      surfaceContainerHigh: Color(0xFF2E2E2E),
      surfaceContainerHighest: Color(0xFF383838),
      // ── Bordi ─────────────────────────────────────────────────────────────
      outline: Color(0xFF595959),
      outlineVariant: Color(0xFF3A3A3A),
      // ── Error / Inverse ───────────────────────────────────────────────────
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      inverseSurface: Color(0xFFE8E8E8),
      onInverseSurface: Color(0xFF1E1E1E),
      inversePrimary: Color(0xFFBF360C),
    );

    return _buildTheme(colorScheme, AppColorsExtension.dark);
  }

  // Font family dell'app
  static const String fontFamily = 'sans-serif';

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AppColorsExtension appColors,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,

      // === Text Theme ===
      // Fonte di verità unica per la tipografia. Prima era assente: i ~66 usi
      // di Theme.of(context).textTheme cadevano sui default Material 2021,
      // mentre i token AppSpacing.font* viaggiavano su un binario separato —
      // due testi con lo stesso ruolo potevano differire di 5px fra schermate.
      //
      // Qui si dichiarano solo fontSize e fontWeight: ThemeData fa il merge di
      // questi stili sopra la baseline Material 2021, quindi letterSpacing,
      // height e i colori per brightness restano quelli nativi di M3.
      textTheme: const TextTheme(
        // ── Headline ────────────────────────────────────────────────────────
        headlineLarge: TextStyle(
          fontSize: AppSpacing.fontHeading, // 28
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          fontSize: AppSpacing.fontTitle, // 24
          fontWeight: FontWeight.w600,
        ),
        // ── Title ───────────────────────────────────────────────────────────
        // titleLarge 22 → 20: leva principale dello snellimento, allineata
        // all'appBarTheme qui sotto.
        titleLarge: TextStyle(
          fontSize: AppSpacing.fontLg, // 20
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: AppSpacing.fontSm, // 16
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontSize: AppSpacing.fontXs, // 14
          fontWeight: FontWeight.w600,
        ),
        // ── Body ────────────────────────────────────────────────────────────
        bodyLarge: TextStyle(
          fontSize: AppSpacing.fontSm, // 16
          fontWeight: FontWeight.w400,
        ),
        // bodyMedium è il nome dell'oggetto: contenuto primario, resta a 14.
        bodyMedium: TextStyle(
          fontSize: AppSpacing.fontXs, // 14
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontSize: AppSpacing.fontXxs, // 12
          fontWeight: FontWeight.w400,
        ),
        // ── Label ───────────────────────────────────────────────────────────
        labelLarge: TextStyle(
          fontSize: AppSpacing.fontXs, // 14
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          fontSize: AppSpacing.fontXxs, // 12
          fontWeight: FontWeight.w500,
        ),
        // M3 mette labelSmall a 11: sotto il floor dichiarato da AppSpacing.
        // Portato a 12 per non avere testo sotto il minimo dell'app.
        labelSmall: TextStyle(
          fontSize: AppSpacing.fontXxs, // 12
          fontWeight: FontWeight.w600,
        ),
      ),

      // === Input Decoration Theme ===
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: AppConstants.emphasisBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: AppConstants.emphasisBorderWidth,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smPlus,
        ),
      ),

      // === Checkbox Theme ===
      // Spuntata: piena e neutra, del colore del testo, con la spunta del
      // colore del fondo, come gli interruttori. Con il solo bordo arancio
      // una colonna di caselle spuntate sembrava una fila di icone. L'arancio
      // pieno resta all'azione principale dello schermo.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return states.contains(WidgetState.disabled)
              ? colorScheme.onSurface.withValues(alpha: AppOpacity.disabled)
              : colorScheme.onSurface;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.surface),
        side: WidgetStateBorderSide.resolveWith((states) {
          final disabled = states.contains(WidgetState.disabled);
          return BorderSide(
            color: disabled
                ? colorScheme.onSurface.withValues(alpha: AppOpacity.disabled)
                : states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            width: AppConstants.emphasisBorderWidth,
          );
        }),
      ),

      // === Switch Theme ===
      // Interruttori neutri: acceso = traccia del colore del testo (bianca
      // sul tema scuro, quasi nera sul chiaro) con pallino del colore della
      // pagina. L'arancio pieno resta alla CTA principale.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? colorScheme.surface
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? colorScheme.onSurface
              : null,
        ),
      ),

      // === Text Selection Theme ===
      // Cursore, selezione e maniglie neutri: l'arancio resta alle azioni.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.onSurface,
        selectionColor: colorScheme.onSurface.withValues(
          alpha: AppOpacity.textSelection,
        ),
        selectionHandleColor: colorScheme.onSurface,
      ),

      // === List Tile Theme ===
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // === Divider Theme ===
      dividerTheme: DividerThemeData(
        thickness: AppConstants.hairlineBorderWidth,
        color: colorScheme.outlineVariant,
      ),

      // === App Bar Theme ===
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        // Material 3 di default usa colorScheme.primary come surfaceTintColor:
        // scrollando contenuto sotto l'AppBar, applica un overlay tinto con
        // quel colore (qui arancione) proporzionale a scrolledUnderElevation,
        // percepito come un cambio di colore dell'AppBar. Disattivato per
        // mantenere l'AppBar sempre dello stesso colore.
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        // titolo della barra, dei fogli e delle sezioni: stesso peso.
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          fontSize: AppSpacing.fontLg, // 20
        ),
      ),

      // === Bottom Sheet Theme ===
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.modalBorderRadius),
          ),
        ),
        backgroundColor: colorScheme.surface,
      ),

      // === Dialog Theme ===
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.modalBorderRadius),
        ),
      ),

      // === Extensions ===
      extensions: [
        appColors,
        // ErrorEmptyThemeExtension calcolata dal ColorScheme attivo
        // (no dipendenza da AppColors statici).
        ErrorEmptyThemeExtension(
          // Token grezzi e non textTheme: ThemeData si costruisce senza
          // BuildContext, quindi qui gli slot non sono raggiungibili. I valori
          // coincidono comunque con titleLarge e bodyLarge.
          emptyStateTitle: TextStyle(
            fontSize: AppSpacing.fontLg, // 20, come titleLarge
            fontWeight: FontWeight.w400, // più leggero: è uno stato vuoto
            color: colorScheme.onSurfaceVariant,
          ),
          emptyStateSubtitle: TextStyle(
            fontSize: AppSpacing.fontSm, // 16px → body → w400
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          emptyStateIconSize: AppSpacing.iconDisplay,
          // Stesso colore del titolo e del sottotitolo: l'icona è parte del
          // messaggio, non un elemento a sé. Al 38% sembrava disabilitata, e
          // in arancione competeva con l'unica cosa toccabile della schermata,
          // che è la CTA.
          emptyStateIconColor: colorScheme.onSurfaceVariant,
          emptyStateTitleColor: colorScheme.onSurfaceVariant,
          emptyStateSubtitleColor: colorScheme.onSurfaceVariant,
          errorStateMessage: const TextStyle(
            fontSize: AppSpacing.fontSm,
            fontWeight: FontWeight.w400,
          ),
          errorStateIconSize: AppSpacing.iconDisplay,
          errorStateIconColor: colorScheme.error,
          errorStateRetryLabel: 'common.retry',
          stateSpacingMd: AppSpacing.md,
          stateSpacingLg: AppSpacing.lg,
          stateSpacingSm: AppSpacing.sm,
        ),
      ],
    );
  }
}

/// Extension per accedere facilmente ai colori custom dal context
extension AppColorsExtensionX on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
