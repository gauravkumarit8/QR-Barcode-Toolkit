import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user preferences (theme mode, auto-save) locally.
/// No network calls — consistent with the app's offline-first design.
class SettingsService {
  static const _themeModeKey = 'theme_mode_v1';
  static const _autoSaveKey = 'auto_save_scans_v1';
  static const _hapticKey = 'haptic_feedback_v1';
  static const _soundKey = 'sound_feedback_v1';

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<bool> getAutoSaveScans() async {
    final prefs = await SharedPreferences.getInstance();
    // Defaults to true — matches the original spec's default-ON behavior.
    return prefs.getBool(_autoSaveKey) ?? true;
  }

  Future<void> setAutoSaveScans(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveKey, value);
  }

  /// Short vibration when a code is scanned. On by default.
  Future<bool> getHapticFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticKey) ?? true;
  }

  Future<void> setHapticFeedback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, value);
  }

  /// Click sound when a code is scanned. Off by default (quiet is safer).
  Future<bool> getSoundFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? false;
  }

  Future<void> setSoundFeedback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
  }
}
