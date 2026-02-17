import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../core/snackbar_util.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({super.key});

  // Input controllers to capture user data
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Create Account", style: theme.textTheme.displayLarge),
                const SizedBox(height: 12),
                Text(
                  "Join the professional quadrant today",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.deepNavy.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 40),

                // User Profile Fields
                _buildStandardTextField(
                  context,
                  hint: "Full Name",
                  icon: Icons.person_outline,
                  controller: nameController,
                ),
                const SizedBox(height: 15),

                _buildStandardTextField(
                  context,
                  hint: "Username",
                  icon: Icons.alternate_email,
                  controller: usernameController,
                ),
                const SizedBox(height: 15),

                _buildStandardTextField(
                  context,
                  hint: "Email Address",
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),
                const SizedBox(height: 15),

                _buildStandardTextField(
                  context,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  controller: passwordController,
                ),
                const SizedBox(height: 30),

                // Primary Action Button wrapped in Obx for reactive loading state
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
                      // Disable button while loading to prevent duplicate Firebase entries
                      onPressed: authController.isLoading.value
                          ? null
                          : () {
                              // Validate input
                              if (emailController.text.trim().isEmpty ||
                                  passwordController.text.trim().isEmpty ||
                                  nameController.text.trim().isEmpty ||
                                  usernameController.text.trim().isEmpty) {
                                SnackbarUtil.error(
                                  "Validation Error",
                                  "Please fill in all fields",
                                );
                                return;
                              }

                              // Call AuthController.register with all parameters
                              authController.register(
                                emailController.text.trim(),
                                passwordController.text.trim(),
                                nameController.text.trim(),
                                usernameController.text.trim(),
                              );
                            },
                      child: authController.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Create Profile",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.deepNavy.withValues(alpha: 0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: const Text(
                        "Sign In",
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

  // Helper widget to build consistent, themed text fields
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
            size: 22,
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
