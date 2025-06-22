import 'package:flutter/material.dart';
import 'package:music_lector/data/repositories/file_repository.dart';
import 'package:music_lector/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de sqflite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Configuración de la ventana
  await windowManager.ensureInitialized();

  // Configuración inicial de la ventana
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720), // Tamaño inicial razonable
    center: true,
    title: 'Music Lector',
    titleBarStyle: TitleBarStyle.hidden, // Ocultar barra de título nativa
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    
    // Maximizar la ventana al inicio (sin ser fullscreen)
    await windowManager.maximize();
  });

  runApp(
    Provider<FileRepositoryImpl>(
      create: (_) => FileRepositoryImpl(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _init() async {
    // Configurar atajos de teclado globales
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Alt+Enter para alternar pantalla completa
      if ((event.logicalKey == LogicalKeyboardKey.altLeft || event.logicalKey == LogicalKeyboardKey.altRight) && event.logicalKey == LogicalKeyboardKey.enter) {
        _toggleFullScreen();
        return true;
      }
      // F11 para alternar pantalla completa
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        _toggleFullScreen();
        return true;
      }
    }
    return false;
  }

  Future<void> _toggleFullScreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullScreen);
    
    // Si salimos del modo pantalla completa, volvemos a maximizar
    if (isFullScreen) {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Atajo para Alt+Enter
        const SingleActivator(LogicalKeyboardKey.enter, alt: true): 
          const _ToggleFullScreenIntent(),
        // Atajo para F11
        const SingleActivator(LogicalKeyboardKey.f11): 
          const _ToggleFullScreenIntent(),
      },
      child: Actions(
        actions: {
          _ToggleFullScreenIntent: CallbackAction<_ToggleFullScreenIntent>(
            onInvoke: (_) => _toggleFullScreen(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: ThemeMode.system,
          ),
        ),
      ),
    );
  }

  // Escucha eventos de la ventana
  @override
  void onWindowEvent(String eventName) {
    // Puedes manejar otros eventos de ventana aquí si es necesario
  }
}

// Intent personalizado para alternar pantalla completa
class _ToggleFullScreenIntent extends Intent {
  const _ToggleFullScreenIntent();
}