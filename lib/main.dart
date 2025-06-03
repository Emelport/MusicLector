import 'package:flutter/material.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Importar el router (_router)

void main() {
  sqfliteFfiInit(); // Inicializa FFI
  databaseFactory = databaseFactoryFfi; // Asigna el factory global

  runApp(
    Provider<FileRepositoryImpl>(
      create: (_) => FileRepositoryImpl(),
      child: const MyApp(),
    ),
  );
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
