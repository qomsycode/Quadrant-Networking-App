import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/profile_controller.dart';
import '../../core/app_theme.dart';

class SkillsEditorDialog extends StatefulWidget {
  const SkillsEditorDialog({super.key});

  @override
  State<SkillsEditorDialog> createState() => _SkillsEditorDialogState();
}

class _SkillsEditorDialogState extends State<SkillsEditorDialog> {
  final skillController = TextEditingController();
  final profileController = Get.find<ProfileController>();

  @override
  void dispose() {
    skillController.dispose();
    super.dispose();
  }

  void _addSkill() async {
    if (skillController.text.trim().isNotEmpty) {
      await profileController.addSkill(skillController.text);
      skillController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Skills'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: skillController,
                decoration: InputDecoration(
                  labelText: 'Add a skill',
                  hintText: 'e.g., Flutter, Python, Leadership',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSkill,
                  ),
                ),
                onSubmitted: (_) => _addSkill(),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final skills =
                    profileController.currentUser.value?.skills ?? [];
                if (skills.isEmpty) {
                  return const Text('No skills added yet');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      onDeleted: () => profileController.removeSkill(skill),
                      backgroundColor: AppTheme.primaryBlue.withAlpha(30),
                      deleteIcon: const Icon(Icons.close),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Done')),
      ],
    );
  }
}
