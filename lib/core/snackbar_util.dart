import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Utility class to show consistent, visually prominent snackbars across the app.
/// All snackbars use a blue background with white text for better visibility.
class SnackbarUtil {
  // Blue background color for snackbars
  static const Color _backgroundColor = Color(0xFF1E88E5);

  /// Show a success snackbar (blue background, white text)
  static void success(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _backgroundColor,
      colorText: Colors.white,
      duration: duration,
    );
  }

  /// Show an info snackbar (blue background, white text)
  static void info(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _backgroundColor,
      colorText: Colors.white,
      duration: duration,
    );
  }

  /// Show an error snackbar (blue background, white text)
  static void error(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _backgroundColor,
      colorText: Colors.white,
      duration: duration,
    );
  }

  /// Show a warning snackbar (blue background, white text)
  static void warning(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _backgroundColor,
      colorText: Colors.white,
      duration: duration,
    );
  }

  /// Show a generic snackbar with blue background (default)
  static void show(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _backgroundColor,
      colorText: Colors.white,
      duration: duration,
    );
  }
}
