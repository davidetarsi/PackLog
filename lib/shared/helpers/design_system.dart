/// Design System components and helpers.
/// 
/// Import questo file per avere accesso a tutti i componenti del design system:
/// ```dart
/// import 'package:stuff_tracker_2/shared/design_system/design_system.dart';
/// ```
library;

// Components
export 'empty_state.dart';
export 'error_state.dart';
export 'bottom_sheet_handle.dart';

// Helpers
export 'dialog_helpers.dart';

// Theme Extension (necessaria per context.errorEmptyTheme)
export '../theme/error_empty_theme_extension.dart';
