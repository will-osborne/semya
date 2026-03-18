import 'package:flutter/material.dart';

class MaterialTheme {
  MaterialTheme._();

  static const Color _primaryLight = Color(0xFF1A3A6B);
  static const Color _primaryDark = Color(0xFF4A7FBF);
  static const Color _accentLight = Color(0xFFD4860B);
  static const Color _accentDark = Color(0xFFF5A623);
  static const Color _backgroundLight = Color(0xFFF5F3EF);
  static const Color _backgroundDark = Color(0xFF121212);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF1E1E1E);
  static const Color _onPrimaryLight = Color(0xFFFFFFFF);
  static const Color _onPrimaryDark = Color(0xFF0D1F3C);
  static const Color _errorColor = Color(0xFFB00020);

  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _primaryLight,
      onPrimary: _onPrimaryLight,
      primaryContainer: const Color(0xFFD6E3FF),
      onPrimaryContainer: const Color(0xFF001A41),
      secondary: _accentLight,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFFFDDB5),
      onSecondaryContainer: const Color(0xFF2C1600),
      tertiary: const Color(0xFF5C6B8A),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFDFE4FF),
      onTertiaryContainer: const Color(0xFF171C35),
      error: _errorColor,
      onError: const Color(0xFFFFFFFF),
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: _surfaceLight,
      onSurface: const Color(0xFF1A1C1E),
      surfaceContainerHighest: const Color(0xFFE1E2EC),
      onSurfaceVariant: const Color(0xFF44464F),
      outline: const Color(0xFF75767F),
      outlineVariant: const Color(0xFFC5C6D0),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: const Color(0xFF2F3033),
      onInverseSurface: const Color(0xFFF2F0F4),
      inversePrimary: _primaryDark,
    );

    return _buildTheme(colorScheme, _backgroundLight);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _primaryDark,
      onPrimary: _onPrimaryDark,
      primaryContainer: const Color(0xFF00306A),
      onPrimaryContainer: const Color(0xFFD6E3FF),
      secondary: _accentDark,
      onSecondary: const Color(0xFF462A00),
      secondaryContainer: const Color(0xFF633F00),
      onSecondaryContainer: const Color(0xFFFFDDB5),
      tertiary: const Color(0xFFBEC6EA),
      onTertiary: const Color(0xFF2B3152),
      tertiaryContainer: const Color(0xFF424769),
      onTertiaryContainer: const Color(0xFFDFE4FF),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: _surfaceDark,
      onSurface: const Color(0xFFE2E2E6),
      surfaceContainerHighest: const Color(0xFF44464F),
      onSurfaceVariant: const Color(0xFFC5C6D0),
      outline: const Color(0xFF8F9099),
      outlineVariant: const Color(0xFF44464F),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: const Color(0xFFE2E2E6),
      onInverseSurface: const Color(0xFF2F3033),
      inversePrimary: _primaryLight,
    );

    return _buildTheme(colorScheme, _backgroundDark);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    Color scaffoldBackground,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.15,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.25,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
