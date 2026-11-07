import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Riporta l'altezza del figlio dopo il layout, solo quando cambia.
///
/// La callback parte in un post-frame (mai durante il layout), quindi può
/// chiamare `setState`. Sostituisce le misure fatte nel `build` con
/// GlobalKey e `SizeChangedLayoutNotifier`.
class HeightReporter extends SingleChildRenderObjectWidget {
  const HeightReporter({
    super.key,
    required this.onHeightChanged,
    required super.child,
  });

  final ValueChanged<double> onHeightChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHeightReporter(onHeightChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderHeightReporter renderObject,
  ) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

/// Render object di [HeightReporter].
class RenderHeightReporter extends RenderProxyBox {
  RenderHeightReporter(this.onHeightChanged);

  ValueChanged<double> onHeightChanged;
  double? _lastHeight;
  bool _scheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _lastHeight || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached) return;
      final current = size.height;
      if (current == _lastHeight) return;
      _lastHeight = current;
      onHeightChanged(current);
    });
  }
}
