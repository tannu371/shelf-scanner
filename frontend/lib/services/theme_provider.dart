import 'package:flutter/material.dart';

/// Global theme mode notifier. Wrap MaterialApp with ValueListenableBuilder
/// and pass `.value` to `themeMode:`.
class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider._() : super(ThemeMode.light);
  static final ThemeProvider instance = ThemeProvider._();

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
