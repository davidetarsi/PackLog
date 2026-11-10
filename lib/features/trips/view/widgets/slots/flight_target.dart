import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// La riga di un oggetto che sta per atterrare: occupa il suo posto ma non si
/// vede finché [itemId] è fra gli oggetti in volo ([hidden]).
class FlightTarget extends StatelessWidget {
  const FlightTarget({
    super.key,
    required this.hidden,
    required this.itemId,
    required this.child,
  });

  final ValueListenable<Set<String>>? hidden;
  final String itemId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final flying = hidden;
    if (flying == null) return child;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: flying,
      child: child,
      builder: (_, ids, row) => Visibility(
        visible: !ids.contains(itemId),
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: row!,
      ),
    );
  }
}
