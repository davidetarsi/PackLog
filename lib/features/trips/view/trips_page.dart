import 'package:flutter/material.dart';
import 'trips_screen.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: TripsScreen()),
    );
  }
}

