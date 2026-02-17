import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/profile_controller.dart';
import '../../models/user_model.dart';
import '../../core/app_theme.dart';
import 'profile_page.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileController _profileController = Get.find<ProfileController>();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Your Network",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: "Following"),
            Tab(text: "Followers"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowingList(isDark),
          _buildFollowersList(isDark),
        ],
      ),
    );
  }

  Widget _buildFollowingList(bool isDark) {
    return FutureBuilder<List<UserModel>>(
      future: _profileController.getUserFollowing(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return _buildEmptyState(
            "You aren't following anyone yet.",
            "Find people to follow in the Discovery tab.",
            Icons.person_add_outlined,
            isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user, isFollowingValid: true, isDark: isDark);
          },
        );
      },
    );
  }

  Widget _buildFollowersList(bool isDark) {
    return FutureBuilder<List<UserModel>>(
      future: _profileController.getUserFollowers(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return _buildEmptyState(
            "No followers yet.",
            "Complete your profile to attract more connections.",
            Icons.people_outlined,
            isDark,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            // For followers list, we need to check if WE follow THEM back
            // This is slightly expensive but necessary for the correct button state
            // Or we can just show "Remove" button if we want to block them (not implemented yet)
            // For now, let's show the standard card which handles logic
            return _buildUserCard(user, isFollowingValid: false, isDark: isDark);
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user,
      {required bool isFollowingValid, required bool isDark}) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withAlpha(10) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(30),
        ),
      ),
      child: InkWell(
        onTap: () {
           // Navigate to user profile
           _profileController.loadUserProfile(user.uid);
           Navigator.of(context).push(
             MaterialPageRoute(
               builder: (_) => ProfilePage(userId: user.uid),
             ),
           );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primaryBlue.withAlpha(30),
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0] : "U",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      user.headline ?? "Member",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
                    ),
                  ],
                ),
              ),
              Obx(() {
                // Real-time update of button state
                final amIFollowing = _profileController.currentUser.value?.following
                        .contains(user.uid) ??
                    false;

                return GestureDetector(
                  onTap: () {}, // Absorb taps to prevent InkWell from triggering
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        if (amIFollowing) {
                           _showUnfollowConfirmation(context, user);
                        } else {
                          _profileController.followUser(user.uid);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amIFollowing
                            ? Colors.transparent
                            : AppTheme.primaryBlue,
                        foregroundColor: amIFollowing
                            ? (isDark ? Colors.white : AppTheme.primaryBlue)
                            : Colors.white,
                        elevation: 0,
                        side: BorderSide(
                          color: amIFollowing
                              ? (isDark ? Colors.white54 : AppTheme.primaryBlue)
                              : Colors.transparent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        amIFollowing ? "Unfollow" : "Follow",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      String title, String subtitle, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showUnfollowConfirmation(BuildContext context, UserModel user) {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
         title: const Text("Unfollow User?"),
         content: Text(
           "Do you want to unfollow ${user.fullName}? You won't see their posts in your feed.",
         ),
         actions: [
           TextButton(
             onPressed: () => Get.back(), 
             child: const Text("Cancel"),
           ),
           TextButton(
             onPressed: () {
               _profileController.unfollowUser(user.uid);
               Get.back();
               // Ideally we should refresh the list here, but Stream/Obx might handle button state
               // To remove from list, we need to refresh the FutureBuilder.
               // For now, simpler to just update button state instantly.
               setState(() {}); 
             },
             child: const Text("Unfollow", style: TextStyle(color: Colors.red)),
           ),
         ],
       ),
     );
   }
}
