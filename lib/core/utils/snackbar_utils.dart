import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showMessage(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      duration: const Duration(seconds: 3),
      dismissDirection: DismissDirection.down,
      elevation: 4,
      backgroundColor: Colors.blue[900]?.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      animation: CurvedAnimation(
        parent: const AlwaysStoppedAnimation(1),
        curve: Curves.elasticOut,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
