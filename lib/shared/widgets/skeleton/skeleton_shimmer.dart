import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/app_constants.dart';

/// Avvolge [child] nell'animazione shimmer usando i token M3 del tema corrente.
/// I widget figli devono usare [SkeletonBox] (sfondo bianco opaco) come placeholder:
/// il bianco opaco funge da maschera che "rivela" il gradiente shimmer sottostante.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainerHigh,
      child: child,
    );
  }
}

/// Rettangolo opaco bianco usato come placeholder nell'animazione shimmer.
/// Il colore bianco funge da maschera: il gradiente shimmer appare
/// attraverso le aree bianche, mentre le aree trasparenti mostrano lo sfondo.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppConstants.badgeBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
