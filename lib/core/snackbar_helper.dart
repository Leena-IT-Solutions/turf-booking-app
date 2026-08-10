import 'package:flutter/material.dart';

/// Shared SnackBar helpers. Replaces the 3 independently duplicated
/// `_showError`/`_showSuccess` method pairs (identical bodies) that
/// previously existed in AuthScreen, MainScreen, and MapPickerScreen.
class SnackbarHelper {
  SnackbarHelper._();

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }
}
