import 'package:flutter/material.dart';
import 'tokens.dart';

/// ThemeData 桥接
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Tokens.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: Tokens.accent,
        secondary: Tokens.accentLight,
        surface: Tokens.bgElevated,
        error: Tokens.danger,
      ),
      iconTheme: const IconThemeData(color: Tokens.textPrimary),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Tokens.textPrimary,
          fontSize: Tokens.fontTitle,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Tokens.textPrimary,
          fontSize: Tokens.fontBody,
        ),
        bodyMedium: TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
        ),
      ),
    );
  }
}
