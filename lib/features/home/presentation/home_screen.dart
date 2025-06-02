import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Importar topBar
      appBar: AppBar(
        title: const Text('MusicLector - Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/config');
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '¡Bienvenido a MusicLector!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
