import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Added GetX for navigation/service access
import '../../core/app_theme.dart';
import '../../services/auth_service.dart'; // Import your AuthService
import '../auth/splash_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the AuthService to handle the actual logout
    final authService = Get.find<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Settings & Privacy",
          style: TextStyle(
            color: AppTheme.deepNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.deepNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader("Account"),
          _buildSettingTile(
            Icons.person_outline,
            "Personal Information",
            "qomsyy@gmail.com",
          ),
          _buildSettingTile(
            Icons.lock_outline,
            "Security",
            "Password, Two-factor auth",
          ),

          const Divider(),
          _buildSectionHeader("Preferences"),
          _buildSettingTile(
            Icons.notifications_none,
            "Notifications",
            "Push, Email, SMS",
          ),
          _buildSettingTile(
            Icons.visibility_outlined,
            "Privacy",
            "Who can see your posts",
          ),
          _buildSettingTile(
            Icons.dark_mode_outlined,
            "Display & Sound",
            "Dark mode, text size",
          ),

          const Divider(),
          _buildSectionHeader("Support"),
          _buildSettingTile(
            Icons.help_outline,
            "Help Center",
            "FAQs and support",
          ),
          _buildSettingTile(
            Icons.info_outline,
            "About Quadrant",
            "Version 1.0.0",
          ),

          const Divider(),
          _buildSectionHeader("Session"),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Log out",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Exit qomsyy@gmail.com"),
            trailing: const Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.red,
            ),
            onTap: () async {
              // Sign out from Firebase
              await authService.signOut();

              // Clear all GetX controllers to reset state
              Get.deleteAll(force: true);

              // Go through splash screen for proper auth state check
              Get.offAll(() => const SplashScreen());
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Section Header: Small, professional sub-labels
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Setting Tile: Standardized row for settings options
  Widget _buildSettingTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.deepNavy),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: () {
        // Future: Add navigation to specific settings pages
      },
    );
  }
}
