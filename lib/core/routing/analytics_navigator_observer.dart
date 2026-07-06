import 'package:flutter/widgets.dart';

import '../analytics/core_analytics_service.dart';

/// Tracks screen views via GoRouter's root navigator.
///
/// Fires a `screen_view` analytics event on [didPush] (new screen pushed) and
/// [didReplace] (e.g. redirect swap). Tab switches inside [StatefulShellRoute]
/// branches are handled separately by [MainShell].
///
/// Screen name = [Route.settings.name], which GoRouter sets to the resolved
/// URI (e.g. `/houses/abc123`). Anonymous/nameless routes are silently skipped.
class AnalyticsNavigatorObserver extends NavigatorObserver {
  final CoreAnalyticsService _analytics;

  AnalyticsNavigatorObserver(this._analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.trackScreenView(name);
  }
}
