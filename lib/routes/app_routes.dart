import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_lector/features/config/presentation/config_screen.dart';
import 'package:music_lector/features/home/presentation/home_screen.dart';

final router = GoRouter(
  routes: <RouteBase>[
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
  ]
);