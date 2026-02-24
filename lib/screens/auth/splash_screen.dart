import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import 'sign_in_screen.dart';
import '../main/main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  /// Determines if we go to Home or Login based on Firebase Session
  /// Firebase is already initialized, just check user and show nice splash
  Future<void> _checkUserStatus() async {
    // Firebase is ready at this point, just check cached user
    User? user = FirebaseAuth.instance.currentUser;

    // Show splash for 3 seconds for nice branding UX
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    if (user != null) {
      Get.offAll(() => const MainLayout());
    } else {
      Get.offAll(() => SignInScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          AppTheme.primaryBlue, // Background color from central theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branding Logo
            Image.asset(
              'assets/logo_q.png',
              width: 140,
              color: AppTheme.glassWhite,
            ),
            const SizedBox(height: 24),

            // Tagline with premium spacing
            Text(
              "PREMIUM NETWORKING APP",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.glassWhite,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 40),

            // Subtle loader to indicate background processing
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.glassWhite.withValues(alpha: 0.5),
              ),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
