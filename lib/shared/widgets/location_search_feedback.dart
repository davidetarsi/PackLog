import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/location_search_service.dart';
import 'ds_inline_error.dart';

/// Messaggio condiviso nei campi casa, meta e tappa, senza perdere il focus.
class LocationSearchFeedback extends StatelessWidget {
  const LocationSearchFeedback({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: DsInlineError(
      message:
          (error is GeocodeRateLimitException
                  ? 'location_search.rate_limit_reached'
                  : 'location_search.failed')
              .tr(),
      onRetry: onRetry,
    ),
  );
}
