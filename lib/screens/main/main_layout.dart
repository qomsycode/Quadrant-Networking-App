import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../controllers/theme_controller.dart';
import '../../services/auth_service.dart';
import 'home_feed.dart';
import 'jobs.dart';
import 'post.dart';
import 'notifications.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'bookmarks_page.dart';
import 'discovery_page.dart';
import 'search_results_page.dart';
import 'chat_list_page.dart';
import '../../controllers/chat_controller.dart';

/// ==========================================
/// MAIN LAYOUT (Navigation Hub)
/// ==========================================
///
/// This widget serves as the primary shell of the application after 
/// successful authentication. It manages global navigation and 
/// persistent UI elements like the AppBar, Drawer, and BottomBar.
///
/// KEY ARCHITECTURE:
/// ------------------------------------------
/// 1. IndexedStack: We use an IndexedStack to preserve the state of 
///    all main pages (Home, Discovery, Jobs, Profile). Switching tabs 
///    does NOT reload the page, providing a "Native App" feel.
/// 2. Reactive UI: Wraps the entire Scaffold in an 'Obx' listener to 
///    automatically react to global theme changes or chat unread counts.
/// 3. Navigation Logic: 
///    - BottomNavigationBar: Primary app sections.
///    - Drawer: Secondary features (Bookmarks, Settings).
///    - Search: Global search entry point in the AppBar.
///
/// REAL-TIME INTEGRATION:
/// ------------------------------------------
/// - Profile Picture: Listens to a Firestore stream for the current user 
///   to ensure the AppBar avatar is always up to date.
/// - Chat Badge: Listens to the 'ChatController' to show unread message 
///   counts on the chat icon.
///
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../controllers/theme_controller.dart';
import '../../services/auth_service.dart';
import 'home_feed.dart';
import 'jobs.dart';
import 'post.dart';
import 'notifications.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'bookmarks_page.dart';
import 'discovery_page.dart';
import 'search_results_page.dart';
import 'chat_list_page.dart';
import '../../controllers/chat_controller.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 1:
        return "Network";
      case 3:
        return "Job Board";
      case 4:
        return "Notifications";
      case 5:
        return "My Profile"; // Added title for the profile view
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final bool isDarkMode = themeController.isDarkMode;
      bool isHome = _selectedIndex == 0;
      bool isPost = _selectedIndex == 2;

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildSideDrawer(context),
        appBar: isPost
            ? null
            : AppBar(
                backgroundColor: isHome
                    ? (isDarkMode ? AppTheme.deepNavy : AppTheme.primaryBlue)
                    : Theme.of(context).appBarTheme.backgroundColor,
                elevation: 0,
                centerTitle: true,
                leading: isHome
                    ? Builder(
                        builder: (context) => StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                              .snapshots(),
                          builder: (context, snapshot) {
                            String? profileImageUrl;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              profileImageUrl = data['profileImageUrl'];
                            }
                            return GestureDetector(
                              onTap: () => Scaffold.of(context).openDrawer(),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircleAvatar(
                                  backgroundColor: Colors.white24,
                                  backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                                      ? NetworkImage(profileImageUrl)
                                      : null,
                                  child: (profileImageUrl == null || profileImageUrl.isEmpty)
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : null,
                title: isHome
                    ? _buildSearchField()
                    : Text(
                        _getPageTitle(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppTheme.deepNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                actions: isHome
                    ? [
                        // Chat icon with unread badge
                        Obx(() {
                          final chatController = Get.find<ChatController>();
                          final unread = chatController.totalUnread.value;
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ChatListPage()),
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ]
                    : null,
              ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            HomeFeedPage(),
            DiscoveryPage(), // Changed from NetworkPage to DiscoveryPage
            PostPage(),
            JobsPage(),
            NotificationsPage(),
            ProfilePage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex >= 5
              ? 0
              : _selectedIndex, // Reset highlight if on Profile
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDarkMode ? AppTheme.deepNavy : Colors.white,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: isDarkMode
              ? Colors.white70
              : AppTheme.deepNavy.withAlpha(120),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              label: "Network",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined),
              label: "Post",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              label: "Jobs",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none),
              label: "Alerts",
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSideDrawer(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final authService = Get.find<AuthService>();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Drawer(
      child: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .snapshots(),
            builder: (context, snapshot) {
              String fullName = "Professional";
              String username = "user";
              String initial = "Q";

              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                fullName = data['fullName'] ?? "Professional";
                username = data['username'] ?? "handle";
                // Safety check: Ensure fullName is not empty before grabbing index [0]
                initial = (fullName.isNotEmpty)
                    ? fullName[0].toUpperCase()
                    : "Q";
              }

              final String? profileImageUrl = (snapshot.hasData && snapshot.data!.exists)
                  ? (snapshot.data!.data() as Map<String, dynamic>)['profileImageUrl']
                  : null;

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppTheme.primaryBlue),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl.isEmpty)
                      ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        )
                      : null,
                ),
                accountName: Text(
                  fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                accountEmail: Text("@$username"),
                otherAccountsPictures: [
                  GestureDetector(
                    onTap: () => themeController.toggleTheme(),
                    child: Icon(
                      themeController.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedIndex = 5); // Switch to ProfilePage index
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text("Bookmarks"),
            onTap: () {
              Navigator.pop(context);
              Get.to(
                () => const BookmarksPage(),
                transition: Transition.cupertino,
                duration: const Duration(milliseconds: 500),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings & Privacy"),
            onTap: () {
              Navigator.pop(context);
              Get.to(
                () => const SettingsPage(),
                transition: Transition.cupertino,
                duration: const Duration(milliseconds: 500),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              "Sign Out",
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              await authService.signOut();
              Get.offAllNamed('/login');
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              " © 2026 Quadrant Inc.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => const SearchResultsPage(),
          transition: Transition.cupertino,
          duration: const Duration(milliseconds: 300),
        );
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            SizedBox(width: 12),
            Icon(Icons.search, color: Colors.white70, size: 20),
            SizedBox(width: 8),
            Text(
              "Search Quadrant",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
