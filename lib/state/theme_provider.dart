import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;
  ThemeModeNotifier(this.ref) : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    final stored = ref.read(storageServiceProvider).loadThemeMode();
    switch (stored) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(storageServiceProvider).saveThemeMode(mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier(ref));
