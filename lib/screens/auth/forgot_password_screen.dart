import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/app_theme.dart';
import '../../core/snackbar_util.dart';

class ForgotPasswordScreen extends StatelessWidget {
  ForgotPasswordScreen({super.key});

  final TextEditingController _emailController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Clean white
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : AppTheme.deepNavy,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  "Reset Password",
                  style: theme.textTheme.displayLarge, // Professional Bold Navy
                ),
                const SizedBox(height: 12),
                Text(
                  "Enter your email address and we will send you a link to reset your account access.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.deepNavy.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 40),

                // Standardized Input Field
                _buildStandardTextField(
                  context: context,
                  hint: "Email Address",
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 30),

                // Primary Action Button
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
                      onPressed: _authController.isLoading.value
                          ? null
                          : () {
                              _authController.resetPassword(
                                _emailController.text,
                              );
                            },
                      child: _authController.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Send Reset Link",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable component matching your Sign In/Sign Up design
  Widget _buildStandardTextField({
    required String hint,
    required IconData icon,
    required BuildContext context,
    required TextEditingController controller,
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
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
