import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';
import '../main/main_layout.dart';

class SignInScreen extends StatelessWidget {
  SignInScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // 1. Define a reactive loading variable
  final RxBool isLoading = false.obs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Get.find<AuthService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Welcome Back", style: theme.textTheme.displayLarge),
                const SizedBox(height: 12),
                Text(
                  "Sign in to continue your professional journey",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.deepNavy.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 50),

                _buildStandardTextField(
                  context,
                  hint: "Email Address",
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),
                const SizedBox(height: 20),

                _buildStandardTextField(
                  context,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: passwordController,
                ),
                const SizedBox(height: 15),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Get.to(() => ForgotPasswordScreen()),
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 2. Wrap the button in Obx to listen for isLoading changes
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // 3. Disable button while loading to prevent double-taps
                      onPressed: isLoading.value
                          ? null
                          : () async {
                              isLoading.value = true; // Start Loading

                              final user = await authService.signIn(
                                email: emailController.text.trim(),
                                password: passwordController.text.trim(),
                              );

                              isLoading.value = false; // Stop Loading

                              if (user != null) {
                                Get.offAll(() => const MainLayout());
                              }
                            },
                      child: isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.deepNavy.withValues(alpha: 0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.to(() => SignUpScreen()),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardTextField(
    BuildContext context, {
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : AppTheme.deepNavy,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: AppTheme.primaryBlue.withValues(alpha: 0.7),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white30
                : AppTheme.deepNavy.withValues(alpha: 0.4),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 20,
          ),
        ),
      ),
    );
  }
}
