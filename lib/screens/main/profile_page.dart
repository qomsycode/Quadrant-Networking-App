import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../core/snackbar_util.dart';
import '../../controllers/post_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../models/education_model.dart';
import '../../services/cloudinary_widget_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'edit_profile_page.dart';
import 'experience_editor_dialog.dart';
import 'education_editor_dialog.dart';
import 'project_editor_dialog.dart';
import 'followers_list_page.dart';
import 'chat_page.dart';

class ProfilePage extends StatelessWidget {
  final String? userId; // Optional: If null, shows current user

  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ProfileController profileController = Get.find<ProfileController>();

    // Determine which user to show
    // We wrap the whole Scaffold in Obx to react to user changes
    return Obx(() {
      UserModel? user;
      if (userId != null && userId != currentUid) {
        user = profileController.selectedUser.value;
      } else {
        user = profileController.currentUser.value;
      }

      if (user == null) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
          body: userId != null
              ? const Center(child: CircularProgressIndicator())
              : _buildEmptyProfileState(),
        );
      }

      final UserModel actualUser = user!;
      final isOwnProfile = currentUid == actualUser.uid;

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: userId != null
            ? AppBar(
                title: Text(actualUser.username.isNotEmpty ? "@${actualUser.username}" : "Profile"),
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  color: isDark ? Colors.white : Colors.black,
                ),
              )
            : null,
        body: DefaultTabController(
          length: 4, // Posts, Experience, Education, Media
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(context, actualUser, isDark, isOwnProfile),
                ),
                SliverToBoxAdapter(
                  child: _buildStatsSection(context, actualUser, isDark),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      labelColor: AppTheme.primaryBlue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.primaryBlue,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: "Posts"),
                        Tab(text: "Experience"),
                        Tab(text: "Education"),
                        Tab(text: "Media"),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              children: [
                _buildPostTab(context, actualUser, isDark, isOwnProfile),
                _buildExperienceTab(context, actualUser, isDark, isOwnProfile),
                _buildEducationTab(context, actualUser, isDark, isOwnProfile),
                _buildMediaTab(context, actualUser, isDark, isOwnProfile),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Empty State Helper
  Widget _buildEmptyProfileState() {
    return const Center(child: Text("Profile not found"));
  }

  /// Profile Header Widget
  Widget _buildProfileHeader(
    BuildContext context,
    UserModel user,
    bool isDark,
    bool isOwnProfile,
  ) {
    String name = user.fullName;
    String headline = user.headline ?? "Member of The Quadrant";
    String bio = user.bio ?? "No bio added yet.";
    String location = user.location ?? "Remote";
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "Q";

    final ProfileController profileController = Get.find<ProfileController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Profile avatar with optional update for own profile
              GestureDetector(
                onTap: isOwnProfile
                    ? () async {
                        SnackbarUtil.info('Uploading', 'Opening upload widget...');
                        final url = await CloudinaryWidgetService.uploadFile(
                            mediaType: 'image');

                        if (url != null) {
                          await profileController.updateProfile(
                            fullName: user.fullName,
                            profileImageUrl: url,
                          );
                          SnackbarUtil.success(
                              'Success', 'Profile picture updated!');
                        } else {
                          SnackbarUtil.info('Cancelled', 'Upload cancelled');
                        }
                      }
                    : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primaryBlue,
                      child: (user.profileImageUrl != null &&
                              user.profileImageUrl!.isNotEmpty)
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: CloudinaryService.optimizeUrl(
                                    user.profileImageUrl!,
                                    width: 250),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    SkeletonLoader.circle(size: 64),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person, color: Colors.white),
                              ),
                            )
                          : Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (isOwnProfile)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              // Actions
              if (isOwnProfile)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  child: const Text("Edit Profile"),
                )
              else
                Obx(() {
                  final isFollowing =
                      profileController.currentUser.value?.following.contains(
                            user.uid,
                          ) ??
                          false;

                  return Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (isFollowing) {
                            _showUnfollowConfirmation(
                              context,
                              user.fullName,
                              profileController,
                              user.uid,
                            );
                          } else {
                            profileController.followUser(user.uid);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.transparent
                              : AppTheme.primaryBlue,
                          foregroundColor: isFollowing
                              ? AppTheme.primaryBlue
                              : Colors.white,
                          side: BorderSide(
                            color: AppTheme.primaryBlue,
                            width: isFollowing ? 1.5 : 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(isFollowing ? "Following" : "Follow"),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: AppTheme.primaryBlue),
                        onPressed: () async {
                          Get.snackbar('Opening chat...', 'Please wait',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 1));
                          try {
                            final chatController = Get.find<ChatController>();
                            final chatId =
                                await chatController.openChat(user.uid);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    chatId: chatId,
                                    otherUserId: user.uid,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            Get.snackbar('Error', 'Could not open chat: $e',
                                snackPosition: SnackPosition.BOTTOM);
                          }
                        },
                      ),
                    ],
                  );
                }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.deepNavy,
            ),
          ),
          if (headline.isNotEmpty)
            Text(
              headline,
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            bio,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                location,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stats Section
  Widget _buildStatsSection(BuildContext context, UserModel user, bool isDark) {
    final followersCount = user.followers.length;
    final followingCount = user.following.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FollowersListPage(
                    userId: user.uid,
                    initialTabIndex: 0,
                  ),
                ),
              );
            },
            child: _buildStatItem("$followersCount", "Followers", isDark),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FollowersListPage(
                    userId: user.uid,
                    initialTabIndex: 1,
                  ),
                ),
              );
            },
            child: _buildStatItem("$followingCount", "Following", isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.deepNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- TABS ---

  /// Posts Tab
  Widget _buildPostTab(
    BuildContext context,
    UserModel user,
    bool isDark,
    bool isOwnProfile,
  ) {
    final PostController postController = Get.find<PostController>();
    return StreamBuilder<List<PostModel>>(
      stream: postController.getUserPostsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final myPosts = snapshot.data ?? [];

        if (myPosts.isEmpty) {
          return Center(
            child: Text(
              isOwnProfile
                  ? "You haven't posted anything yet."
                  : "No posts to show.",
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          itemCount: myPosts.length,
          padding: const EdgeInsets.only(bottom: 50),
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildInsightCard(
            context,
            myPosts[index],
            isDark,
          ),
        );
      },
    );
  }

  /// Experience Tab (Includes Skills at top)
  Widget _buildExperienceTab(
    BuildContext context,
    UserModel user,
    bool isDark,
    bool isOwnProfile,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Skills Section embedded here
        if (user.skills.isNotEmpty || isOwnProfile) ...[
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
              'Skills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.deepNavy,
              ),
              ),
              if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => print("Open Skills Editor"), 
                // We'd ideally import/use SkillsEditorDialog here but let's keep it simple
                // or just rely on existing imports if any
              ),
            ],
            ),
            const SizedBox(height: 8),
            if (user.skills.isEmpty)
             const Text("No skills added yet.", style: TextStyle(color: Colors.grey))
            else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.skills.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: AppTheme.primaryBlue.withAlpha(20),
                  labelStyle: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 30),
        ],
        

        // Experience List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Experience',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.deepNavy,
              ),
            ),
            if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ExperienceEditorDialog(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (user.experiences.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                isOwnProfile
                    ? 'Add your work experience to stand out'
                    : 'No experiences added yet',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: user.experiences.length,
            itemBuilder: (context, index) {
              final exp = user.experiences[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  exp.company,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwnProfile)
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Text('Edit'),
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => ExperienceEditorDialog(
                                      experience: exp,
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  child: const Text('Delete'),
                                  onTap: () => Get.find<ProfileController>()
                                      .deleteExperience(exp.id),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${exp.getDurationString()} • ${exp.isCurrentRole ? 'Present' : ''}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (exp.location.isNotEmpty)
                        Text(
                          exp.location,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      if (exp.description != null &&
                          exp.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          exp.description!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Education Tab
  Widget _buildEducationTab(
    BuildContext context,
    UserModel user,
    bool isDark,
    bool isOwnProfile,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Education',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.deepNavy,
              ),
            ),
            if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const EducationEditorDialog(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (user.education.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                isOwnProfile
                    ? 'Add your education history'
                    : 'No education added yet',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: user.education.length,
            itemBuilder: (context, index) {
              final edu = user.education[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                       BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  edu.school,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  "${edu.degree}, ${edu.fieldOfStudy}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwnProfile)
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                // Edit not fully implemented in Dialog yet, so just Delete for now or Edit which acts like Add
                                // Let's allow Edit since I added handling safely in dialog 
                                PopupMenuItem(
                                  child: const Text('Edit'),
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => EducationEditorDialog(education: edu),
                                    ),
                                ),
                                PopupMenuItem(
                                  child: const Text('Delete'),
                                  onTap: () => Get.find<ProfileController>()
                                      .deleteEducation(edu.id),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${edu.startDate.year} - ${edu.isCurrent ? 'Present' : (edu.endDate?.year ?? '')}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                       if (edu.description != null &&
                          edu.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          edu.description!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Media Tab (Projects)
  Widget _buildMediaTab(
    BuildContext context,
    UserModel user,
    bool isDark,
    bool isOwnProfile,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Projects / Media',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.deepNavy,
              ),
            ),
            if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ProjectEditorDialog(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (user.projects.isEmpty)
          Center(
             child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
              isOwnProfile
                  ? 'Showcase your projects and media'
                  : 'No media available',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
             ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: user.projects.length,
            itemBuilder: (context, index) {
              final project = user.projects[index];
              return GestureDetector(
                onTap: () {
                   // Open project details or link
                   if (project.link != null && project.link!.isNotEmpty) {
                     // In a real app, launch URL
                     SnackbarUtil.info('Project Link', project.link!);
                   }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                    boxShadow: [
                       BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withAlpha(30),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            image: (project.imageUrls.isNotEmpty)
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(
                                        CloudinaryService.optimizeUrl(
                                            project.imageUrls.first,
                                            width: 400)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: project.imageUrls.isEmpty
                              ? Center(
                                  child: Icon(Icons.folder_open,
                                      size: 40,
                                      color: AppTheme.primaryBlue.withAlpha(100)),
                                )
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (project.description != null)
                              Text(
                                project.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                      if(isOwnProfile)
                        Row(
                           mainAxisAlignment: MainAxisAlignment.end,
                           children: [
                             IconButton(
                               icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                               onPressed: () => Get.find<ProfileController>().deleteProject(project.id),
                             )
                           ],
                        )
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Helper for Repost/Insight Card (Copied from previous implementation)
  Widget _buildInsightCard(BuildContext context, PostModel post, bool isDark) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool isRepost =
        post.uid != currentUid && post.reposts.contains(currentUid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRepost) ...[
            Row(
              children: [
                Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  "You reposted",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryBlue,
                backgroundImage: (post.profileImageUrl != null &&
                        post.profileImageUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(
                        CloudinaryService.optimizeUrl(post.profileImageUrl!,
                            width: 100),
                      )
                    : null,
                child: (post.profileImageUrl == null ||
                        post.profileImageUrl!.isEmpty)
                    ? Text(
                        post.profileInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "@${post.username}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "· ${post.getTimeAgo()}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (post.mediaUrls.isNotEmpty &&
                        post.mediaType == 'image') ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: CloudinaryService.optimizeUrl(
                              post.mediaUrls.first,
                              width: 800),
                          placeholder: (context, url) => SkeletonLoader.square(
                            size: 200,
                            borderRadius: 12,
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text("${post.commentCount}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(width: 20),
                        Icon(Icons.favorite_border,
                            size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text("${post.likes}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const SizedBox(width: 20),
                        Icon(Icons.repeat, size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text("${post.reposts.length}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUnfollowConfirmation(
      BuildContext context,
      String username,
      ProfileController controller,
      String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Unfollow $username?"),
        content:
            const Text("Their posts will no longer appear in your home feed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              controller.unfollowUser(uid);
              Navigator.pop(context);
            },
            child: const Text("Unfollow"),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Add background color to handle scrolling behind status bar or header overlap
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
