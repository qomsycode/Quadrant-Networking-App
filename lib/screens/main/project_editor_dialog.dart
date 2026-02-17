import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/profile_controller.dart';
import '../../models/project_model.dart';
import '../../core/app_theme.dart';

import '../../core/snackbar_util.dart';
import '../../services/cloudinary_widget_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cloudinary_service.dart';

class ProjectEditorDialog extends StatefulWidget {
  final Project? project;

  const ProjectEditorDialog({super.key, this.project});

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController linkController;
  final profileController = Get.find<ProfileController>();
  String? coverImageUrl;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      titleController = TextEditingController(text: widget.project!.title);
      descriptionController = TextEditingController(
        text: widget.project!.description,
      );

      linkController = TextEditingController(text: widget.project!.link ?? '');
      if (widget.project!.imageUrls.isNotEmpty) {
        coverImageUrl = widget.project!.imageUrls.first;
      }
    } else {
      titleController = TextEditingController();
      descriptionController = TextEditingController();
      linkController = TextEditingController();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Add Project' : 'Edit Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover Image Upload
            GestureDetector(
              onTap: isUploading
                  ? null
                  : () async {
                      setState(() => isUploading = true);
                      final url = await CloudinaryWidgetService.uploadFile(
                        mediaType: 'image',
                      );
                      setState(() {
                        isUploading = false;
                        if (url != null) coverImageUrl = url;
                      });
                    },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(100)),
                ),
                child: (coverImageUrl != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: CloudinaryService.optimizeUrl(
                            coverImageUrl!,
                            width: 600,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Add Cover Image",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Project Title',
                hintText: 'e.g., MyApp - Social Network',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Tell us about this project...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkController,
              decoration: const InputDecoration(
                labelText: 'Project Link (Optional)',
                hintText: 'https://github.com/...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        Obx(
          () => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            onPressed: profileController.isLoading.value
                ? null
                : () async {
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty) {
                      SnackbarUtil.error(
                        'Error',
                        'Please fill all required fields',
                      );
                      return;
                    }

                    final String? cover = coverImageUrl;
                    final List<String> images = cover != null ? [cover] : [];

                    if (widget.project == null) {
                      await profileController.addProject(
                        title: titleController.text,
                        description: descriptionController.text,
                        link: linkController.text.isEmpty
                            ? null
                            : linkController.text,
                        imageUrls: images,
                      );
                    } else {
                      // Update project
                      await profileController.deleteProject(widget.project!.id);
                      await profileController.addProject(
                        title: titleController.text,
                        description: descriptionController.text,
                        link: linkController.text.isEmpty
                            ? null
                            : linkController.text,
                        imageUrls: images,
                      );
                    }

                    Navigator.of(context).pop();
                  },
            child: profileController.isLoading.value
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.project == null ? 'Add' : 'Update',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
