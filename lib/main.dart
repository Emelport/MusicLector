import 'package:flutter/material.dart';
import 'package:music_lector/routes/app_routes.dart'; // Importar el router (_router)

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router, // Usamos el _router importado
      debugShowCheckedModeBanner: false,
    );
  }
}
