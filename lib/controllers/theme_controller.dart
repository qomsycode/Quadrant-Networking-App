import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';
  final _isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Loads your saved preference (Light or Dark) on startup
    _isDarkMode.value = _loadThemeFromBox();
  }

  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get theme => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  bool _loadThemeFromBox() => _box.read(_key) ?? false;
  _saveThemeToBox(bool isDarkMode) => _box.write(_key, isDarkMode);

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _saveThemeToBox(_isDarkMode.value);
    // Tells GetMaterialApp to swap the global theme
    Get.changeThemeMode(theme);
  }
}
