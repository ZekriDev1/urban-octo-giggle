import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

/// Splash screen with Lottie animation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to login after animation completes (3 seconds)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white,
              AppColors.primaryPink.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/icons/logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              // Lottie animation
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/Animation - 1748773057383.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
