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
      fontFamily: Tokens.fontFamily,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Tokens.textPrimary,
          fontSize: Tokens.fontTitle,
          fontWeight: Tokens.weightSemiBold,
        ),
        bodyLarge: TextStyle(
          color: Tokens.textPrimary,
          fontSize: Tokens.fontBody,
          fontWeight: Tokens.weightRegular,
        ),
        bodyMedium: TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
          fontWeight: Tokens.weightRegular,
        ),
      ),
    );
  }
}
