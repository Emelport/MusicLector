import 'package:flutter/material.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart'; // Importar el router (_router)

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para inicializar plugins

  sqfliteFfiInit(); // Inicializa FFI
  databaseFactory = databaseFactoryFfi; // Asigna el factory global

   windowManager.ensureInitialized(); // Espera a que se inicialice

  // Opcional: configura opciones como ocultar la barra de título, etc.
  WindowOptions windowOptions = const WindowOptions(
    fullScreen: true, // <-- Aquí se activa pantalla completa
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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
