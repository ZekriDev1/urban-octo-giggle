import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeplaceToi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryPink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryPink,
          primary: AppColors.primaryPink,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
