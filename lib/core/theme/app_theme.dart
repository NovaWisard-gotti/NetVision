import 'package:flutter/material.dart';

/// Paleta de identidad visual exclusiva de NetVision.
///
/// Azul cobalto como color tecnológico principal, aguamarina como acento
/// secundario (nunca dominante, para no confundirse con AquaTech), gris
/// titanio y blanco mineral como neutros, y amarillo señal reservado para
/// resaltar el paquete en movimiento, la ruta activa o advertencias.
class NetVisionColors {
  static const cobalt = Color(0xFF12347A);
  static const cobaltDark = Color(0xFF0C265C);
  static const cobaltLight = Color(0xFF2C56A8);
  static const aqua = Color(0xFF6ED6C8);
  static const titanium = Color(0xFFC8CDD4);
  static const titaniumDark = Color(0xFF4A5361);
  static const mineralWhite = Color(0xFFF5F7FA);
  static const signalYellow = Color(0xFFFFC428);
  static const dangerRed = Color(0xFFE0533D);
  static const successGreen = Color(0xFF3FAE72);

  // Superficies para modo oscuro.
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF141C2E);
  static const darkSurfaceAlt = Color(0xFF1C2740);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: NetVisionColors.cobalt,
      onPrimary: Colors.white,
      secondary: NetVisionColors.aqua,
      onSecondary: NetVisionColors.cobaltDark,
      error: NetVisionColors.dangerRed,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1A2233),
      tertiary: NetVisionColors.signalYellow,
      onTertiary: const Color(0xFF3A2900),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NetVisionColors.mineralWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: NetVisionColors.cobalt,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: NetVisionColors.aqua.withValues(alpha: 0.35),
        surfaceTintColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NetVisionColors.cobalt,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NetVisionColors.cobalt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NetVisionColors.titanium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NetVisionColors.titanium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NetVisionColors.cobalt, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NetVisionColors.cobaltDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: NetVisionColors.titanium,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: NetVisionColors.aqua,
      onPrimary: const Color(0xFF00332C),
      secondary: NetVisionColors.cobaltLight,
      onSecondary: Colors.white,
      error: const Color(0xFFFF7A66),
      onError: const Color(0xFF3A0700),
      surface: NetVisionColors.darkSurface,
      onSurface: const Color(0xFFE7ECF5),
      tertiary: NetVisionColors.signalYellow,
      onTertiary: const Color(0xFF3A2900),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NetVisionColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: NetVisionColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardColor: NetVisionColors.darkSurfaceAlt,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NetVisionColors.darkSurface,
        indicatorColor: NetVisionColors.aqua.withValues(alpha: 0.25),
        surfaceTintColor: NetVisionColors.darkSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NetVisionColors.aqua,
          foregroundColor: const Color(0xFF00332C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NetVisionColors.aqua,
          foregroundColor: const Color(0xFF00332C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NetVisionColors.darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NetVisionColors.titaniumDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: NetVisionColors.titaniumDark),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: NetVisionColors.aqua, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NetVisionColors.darkSurfaceAlt,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: NetVisionColors.titaniumDark,
    );
  }
}

/// Color semántico por tipo de dispositivo, consistente en ambos temas
/// (independiente del brillo, ya que los propios nodos llevan su propio
/// contraste con bordes e íconos).
class DeviceVisuals {
  static const pcColor = NetVisionColors.cobalt;
  static const laptopColor = NetVisionColors.cobaltLight;
  static const serverColor = NetVisionColors.titaniumDark;
  static const switchColor = NetVisionColors.aqua;
  static const routerColor = NetVisionColors.signalYellow;
  static const apColor = Color(0xFF8E7CC3);
}
