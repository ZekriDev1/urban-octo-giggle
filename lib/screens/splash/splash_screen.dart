import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

/// Splash screen with Lottie animation
/// Checks if user is logged in and routes accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnAuthState();
  }

  Future<void> _navigateBasedOnAuthState() async {
    // Wait a bit so splash animation is visible (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user is already logged in
    final authService = AuthService();
    final isLoggedIn = await authService.isUserLoggedIn();

    if (mounted) {
      if (isLoggedIn) {
        // User is logged in, go to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PremiumHomeScreen()),
        );
      } else {
        // User is not logged in, go to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Make the splash background full white per request
      backgroundColor: AppColors.white,
      body: Container(
        color: AppColors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie animation (centered)
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/zqBmErHZt2.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              const SizedBox(height: 20),
              // App name
              Text(
                'DéplaceToi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPink,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
