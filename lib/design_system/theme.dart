import 'package:flutter/material.dart';
import 'tokens.dart';

abstract final class NaTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: NaColors.green).copyWith(
      primary: NaColors.green,
      onPrimary: Colors.white,
      surface: NaColors.cream,
      onSurface: NaColors.ink,
      onSurfaceVariant: NaColors.muted,
      error: NaColors.red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NaRadius.control),
    );
    return base.copyWith(
      scaffoldBackgroundColor: NaColors.cream,
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: NaColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: NaColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: NaColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: NaColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: NaColors.ink,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NaColors.cream,
        foregroundColor: NaColors.ink,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: NaSpace.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NaRadius.card),
          side: const BorderSide(color: NaColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(NaSize.touch, NaSize.touch),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(NaSize.touch, NaSize.touch),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(NaSize.touch, NaSize.touch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(NaSpace.lg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NaRadius.control),
        ),
      ),
      dividerTheme: const DividerThemeData(color: NaColors.border),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
