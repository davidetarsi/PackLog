import 'package:flutter/material.dart';
import 'trips_screen.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste di Viaggio'),
      ),
      body: const TripsScreen(),
    );
  }
}

