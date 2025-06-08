import 'package:flutter/material.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart'; // Importar el router (_router)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await windowManager.ensureInitialized();

  // Opcional: configura opciones como ocultar la barra de título, etc.
  WindowOptions windowOptions = const WindowOptions(
    fullScreen: true,
    title: 'Music Lector',
    center: true,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
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

void toggleFullScreen() async {
  bool isFullScreen = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!isFullScreen);
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
