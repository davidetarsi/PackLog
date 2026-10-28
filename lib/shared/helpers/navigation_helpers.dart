import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension PopOrGo on BuildContext {
  /// Torna alla pagina precedente. Se sotto non c'è nulla (la pagina è stata
  /// aperta con `go`, ad esempio dopo un salvataggio o da un deep link) va a
  /// [fallback] invece di lanciare un'eccezione.
  void popOrGo(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
