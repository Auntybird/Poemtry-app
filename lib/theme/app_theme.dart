import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const ink = Color(0xFF121116);
  static const inkSurface = Color(0xFF1C1A21);
  static const inkSurfaceLight = Color(0xFF262330);
  static const inkBorder = Color(0xFF322E3A);

  static const paper = Color(0xFFF3EEE4);

  static const seal = Color(0xFFB6472F);   // brand / recording
  static const gold = Color(0xFFD8B26B);   // highlight / processing
  static const jade = Color(0xFF6FA787);   // "available" status
  static const crimson = Color(0xFFC0392B); // "unavailable" status
  static const violet = Color(0xFF8E7CC3);

  static const chartPalette = [
    seal, gold, jade, violet, crimson,
    Color(0xFF6E8FA3), Color(0xFFA47C48), Color(0xFF5C7A99), Color(0xFF9B6B9E),
  ];
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.ink,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.seal,
        brightness: Brightness.dark,
      ).copyWith(surface: AppColors.inkSurface),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: AppColors.paper,
            displayColor: AppColors.paper,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.paper),
      ),
      dividerColor: AppColors.inkBorder,
    );
  }
}