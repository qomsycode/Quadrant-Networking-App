import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/profile_controller.dart';
import '../../core/app_theme.dart';
import '../../models/user_model.dart';
import 'profile_page.dart';

class FollowersListPage extends StatefulWidget {
  final String userId;
  final int initialTabIndex; // 0 for Followers, 1 for Following

  const FollowersListPage({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileController _profileController = Get.find<ProfileController>();

  List<UserModel> followers = [];
  List<UserModel> following = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final followersList =
          await _profileController.getUserFollowers(widget.userId);
      final followingList =
          await _profileController.getUserFollowing(widget.userId);

      setState(() {
        followers = followersList;
        following = followingList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading followers/following: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : Colors.black,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(followers, 'No followers yet', isDark),
                _buildUserList(following, 'Not following anyone yet', isDark),
              ],
            ),
    );
  }

  Widget _buildUserList(List<UserModel> users, String emptyMessage, bool isDark) {
    if (users.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user, isDark);
      },
    );
  }

  Widget _buildUserCard(UserModel user, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.withAlpha(30),
        ),
      ),
      child: InkWell(
        onTap: () {
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
                    if (user.headline != null && user.headline!.isNotEmpty)
                      Text(
                        user.headline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Obx(() {
                final amIFollowing = _profileController.currentUser.value
                        ?.following.contains(user.uid) ??
                    false;

                return SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      if (amIFollowing) {
                        _showUnfollowConfirmation(user);
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
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnfollowConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Unfollow User?"),
        content: Text(
          "Do you want to unfollow ${user.fullName}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _profileController.unfollowUser(user.uid);
              Navigator.pop(context);
            },
            child: const Text(
              "Unfollow",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
