import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'ds_button.dart';
import 'ds_empty_state.dart';

/// Contenuto non più disponibile: stessa forma degli errori di caricamento,
/// con una destinazione sicura anziché un tentativo di ricaricamento.
class DsNotFoundState extends StatelessWidget {
  const DsNotFoundState({
    super.key,
    required this.title,
    required this.onAction,
    required this.actionLabel,
    this.message,
    this.icon = Icons.search_off_outlined,
  });

  final String title;
  final String? message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DsEmptyState(
    scrollable: true,
    icon: icon,
    title: title,
    subtitle: message ?? 'common.content_unavailable'.tr(),
    ctaLabel: actionLabel,
    ctaVariant: DsButtonVariant.secondary,
    onCta: onAction,
  );
}
