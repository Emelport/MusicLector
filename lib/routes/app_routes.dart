import 'package:go_router/go_router.dart';
import 'package:music_lector/features/config/presentation/config_screen.dart';
import 'package:music_lector/features/home/presentation/home/home_screen.dart';
import 'package:music_lector/features/home/presentation/Library/pdf_list.dart';
import 'package:music_lector/features/lector/presentation/pdf_viewer.dart';

final router = GoRouter(routes: <RouteBase>[
  GoRoute(
    path: '/',
    builder: (context, state) {
      return const HomeScreen();
    },
  ),
  GoRoute(
    path: '/config',
    builder: (context, state) {
      return const ConfigScreen();
    },
  ),
  GoRoute(
    path: '/library',
    builder: (context, state) {
      return const PdfList();
    },
  ),
  GoRoute(
    path: '/pdf_viewer',
    builder: (context, state) {
      final filePath = state.extra as String;
      return PdfViewer(filePath: filePath);
    },
  ),
]);
