import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/api_keys.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: ApiKeys.supabaseUrl,
    anonKey: ApiKeys.supabaseAnonKey,
  );
  
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
        fontFamily: 'UberMove',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          displaySmall: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          bodySmall: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          labelLarge: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w700),
          labelMedium: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontFamily: 'UberMove', fontWeight: FontWeight.w500),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGrey.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primaryPink, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
