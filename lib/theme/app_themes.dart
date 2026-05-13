import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Friji light & dark themes — used app-wide via [MaterialApp.theme] / [darkTheme].
abstract final class AppThemes {
  static const Color _brandBlue = Color(0xFF2D7DFF);

  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: _brandBlue,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F7FB),
    );
    return _build(cs, Brightness.light);
  }

  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8EBBFF),
      brightness: Brightness.dark,
      surface: const Color(0xFF0E1117),
    );
    return _build(cs, Brightness.dark);
  }

  static ThemeData _build(ColorScheme colorScheme, Brightness brightness) {
    final overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      brightness: brightness,
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 8,
        shadowColor: brightness == Brightness.dark ? Colors.black54 : Colors.black26,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(backgroundColor: colorScheme.surfaceContainerHigh),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        modalBackgroundColor: colorScheme.surfaceContainerHigh,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
      ),
    );
  }
}
