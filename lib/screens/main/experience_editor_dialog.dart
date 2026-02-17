import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/profile_controller.dart';
import '../../models/experience_model.dart';
import '../../core/app_theme.dart';
import '../../core/snackbar_util.dart';

class ExperienceEditorDialog extends StatefulWidget {
  final Experience? experience;

  const ExperienceEditorDialog({super.key, this.experience});

  @override
  State<ExperienceEditorDialog> createState() => _ExperienceEditorDialogState();
}

class _ExperienceEditorDialogState extends State<ExperienceEditorDialog> {
  late TextEditingController titleController;
  late TextEditingController companyController;
  late TextEditingController locationController;
  late TextEditingController descriptionController;
  late DateTime startDate;
  late DateTime? endDate;
  late bool isCurrentRole;
  final profileController = Get.find<ProfileController>();

  @override
  void initState() {
    super.initState();
    if (widget.experience != null) {
      titleController = TextEditingController(text: widget.experience!.title);
      companyController = TextEditingController(
        text: widget.experience!.company,
      );
      locationController = TextEditingController(
        text: widget.experience!.location,
      );
      descriptionController = TextEditingController(
        text: widget.experience!.description ?? '',
      );
      startDate = widget.experience!.startDate;
      endDate = widget.experience!.endDate;
      isCurrentRole = widget.experience!.isCurrentRole;
    } else {
      titleController = TextEditingController();
      companyController = TextEditingController();
      locationController = TextEditingController();
      descriptionController = TextEditingController();
      startDate = DateTime.now();
      endDate = null;
      isCurrentRole = false;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    companyController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : (endDate ?? DateTime.now()),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.experience == null ? 'Add Experience' : 'Edit Experience',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Job Title',
                hintText: 'e.g., Senior Flutter Developer',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: companyController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                hintText: 'e.g., Google',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., San Francisco, CA',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Start: ${startDate.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isCurrentRole ? null : () => _selectDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isCurrentRole ? Colors.grey : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCurrentRole
                            ? 'Currently working'
                            : (endDate != null
                                  ? 'End: ${endDate!.toLocal().toString().split(' ')[0]}'
                                  : 'End: Not set'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isCurrentRole ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: isCurrentRole,
                  onChanged: (value) {
                    setState(() {
                      isCurrentRole = value ?? false;
                      if (isCurrentRole) endDate = null;
                    });
                  },
                ),
                const Expanded(child: Text('Currently working here')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Tell us about your role...',
              ),
              maxLines: 3,
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
                        companyController.text.isEmpty) {
                      SnackbarUtil.error(
                        'Error',
                        'Please fill all required fields',
                      );
                      return;
                    }

                    if (widget.experience == null) {
                      await profileController.addExperience(
                        title: titleController.text,
                        company: companyController.text,
                        location: locationController.text,
                        startDate: startDate,
                        endDate: isCurrentRole ? null : endDate,
                        description: descriptionController.text.isEmpty
                            ? null
                            : descriptionController.text,
                        isCurrentRole: isCurrentRole,
                      );
                    } else {
                      await profileController.updateExperience(
                        experienceId: widget.experience!.id,
                        title: titleController.text,
                        company: companyController.text,
                        location: locationController.text,
                        startDate: startDate,
                        endDate: isCurrentRole ? null : endDate,
                        description: descriptionController.text.isEmpty
                            ? null
                            : descriptionController.text,
                        isCurrentRole: isCurrentRole,
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
                    widget.experience == null ? 'Add' : 'Update',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}
