import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Impostazioni',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Informazioni'),
          subtitle: Text('Versione 1.0.0'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.storage),
          title: Text('Archiviazione'),
          subtitle: Text('Dati salvati localmente'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('Aiuto'),
          subtitle: Text('Gestisci case e oggetti'),
        ),
      ],
    );
  }
}
