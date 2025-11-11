import 'package:flutter/material.dart';

/// DeplaceToi brand colors
class AppColors {
  // Primary pink accent color for DeplaceToi
  static const Color primaryPink = Color(0xFFFF1493); // DeepPink
  static const Color primaryPinkLight = Color(0xFFFF69B4); // HotPink
  static const Color primaryPinkDark = Color(0xFFC71585); // MediumVioletRed
  
  // Secondary colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF808080);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF424242);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPink, primaryPinkLight],
  );
}

