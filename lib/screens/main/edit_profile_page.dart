import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/profile_controller.dart';
import '../../core/app_theme.dart';
import '../../core/snackbar_util.dart';
import '../../services/cloudinary_widget_service.dart';
import 'experience_editor_dialog.dart';
import 'education_editor_dialog.dart';
import 'project_editor_dialog.dart';
import 'skills_editor_dialog.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final nameController = TextEditingController();
  final headlineController = TextEditingController();
  final bioController = TextEditingController();
  final locationController = TextEditingController();

  late ProfileController profileController;
  String? _newProfileImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    profileController = Get.find<ProfileController>();

    // Initialize fields with current user data
    if (profileController.currentUser.value != null) {
      final user = profileController.currentUser.value!;
      nameController.text = user.fullName;
      headlineController.text = user.headline ?? "";
      bioController.text = user.bio ?? "";
      locationController.text = user.location ?? "";
    }
  }

  Future<void> _pickProfileImage() async {
    setState(() => _isUploadingImage = true);
    
    // Open Cloudinary Upload Widget
    final url = await CloudinaryWidgetService.uploadFile(
      mediaType: 'image'
    );
    
    setState(() => _isUploadingImage = false);

    if (url != null) {
      setState(() => _newProfileImageUrl = url);
      SnackbarUtil.success('Success', 'Profile image uploaded. Tap Save to apply.');
    } else {
      SnackbarUtil.info('Cancelled', 'Upload cancelled');
    }
  }

  void updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      SnackbarUtil.error("Error", "Full name is required");
      return;
    }

    await profileController.updateProfile(
      fullName: nameController.text.trim(),
      headline: headlineController.text.trim(),
      bio: bioController.text.trim(),
      location: locationController.text.trim(),
      profileImageUrl: _newProfileImageUrl,
    );

    // Wait for snackbar to be visible
    await Future.delayed(const Duration(milliseconds: 500));
    Get.back();
  }

  @override
  void dispose() {
    nameController.dispose();
    headlineController.dispose();
    bioController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryBlue,
                      backgroundImage: _newProfileImageUrl != null
                          ? NetworkImage(_newProfileImageUrl!)
                          : (profileController.currentUser.value?.profileImageUrl != null &&
                                  profileController.currentUser.value!.profileImageUrl!.isNotEmpty)
                              ? NetworkImage(profileController.currentUser.value!.profileImageUrl!)
                              : null,
                      child: (_newProfileImageUrl == null &&
                              (profileController.currentUser.value?.profileImageUrl == null ||
                                  profileController.currentUser.value!.profileImageUrl!.isEmpty))
                          ? Text(
                              profileController.currentUser.value?.fullName.isNotEmpty == true
                                  ? profileController.currentUser.value!.fullName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: _isUploadingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Full Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Headline/Title
              TextField(
                controller: headlineController,
                decoration: InputDecoration(
                  labelText: "Headline",
                  hintText: "e.g., Senior Flutter Developer",
                  prefixIcon: const Icon(Icons.work),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bio
              TextField(
                controller: bioController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Bio",
                  hintText: "Tell us about yourself...",
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Location
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: "Location",
                  hintText: "e.g., San Francisco, CA",
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Rich Profile Management Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(100)),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.withAlpha(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enhance Your Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Experience Management
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const ExperienceEditorDialog(),
                        ),
                        icon: const Icon(Icons.business),
                        label: const Text('Add Experience'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Project Management
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const ProjectEditorDialog(),
                        ),
                        icon: const Icon(Icons.folder),
                        label: const Text('Add Project'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Education Management
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const EducationEditorDialog(),
                        ),
                        icon: const Icon(Icons.school),
                        label: const Text('Add Education'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Skills Management
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const SkillsEditorDialog(),
                        ),
                        icon: const Icon(Icons.stars),
                        label: const Text('Manage Skills'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: profileController.isLoading.value
                      ? null
                      : updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: profileController.isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
