import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'trips_screen.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('trips.title'.tr()),
      ),
      body: const TripsScreen(),
    );
  }
}

