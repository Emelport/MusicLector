import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_lector/data/features/home/presentation/home/home_screen.dart';
import 'package:music_lector/data/features/lector/presentation/pdf_viewer.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/pdf_viewer',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return PdfViewer(
          filePath: params['path'] as String,
        );
      },
    ),
  ],
);
