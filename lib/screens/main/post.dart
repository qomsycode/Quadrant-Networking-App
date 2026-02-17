import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/post_controller.dart';
import '../../core/app_theme.dart';
import '../../core/snackbar_util.dart';
import '../../services/cloudinary_widget_service.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  late TextEditingController textController;
  final PostController postController = Get.find<PostController>();
  final List<String> selectedMediaUrls = []; // Store URLs instead of XFiles
  String selectedMediaType = 'image'; // image, video, audio, document

  // @mention state
  bool _showMentionSuggestions = false;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _mentionResults = [];
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController();
    textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = textController.text;
    final cursorPos = textController.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) return;

    // Look backward from cursor to find an @ that starts a mention
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt >= 0) {
      final afterAt = textBeforeCursor.substring(lastAt + 1);
      // Check if there's a space before the @mention query — if so, it's complete
      if (!afterAt.contains(' ') && afterAt.isNotEmpty) {
        _mentionStartIndex = lastAt;
        _mentionQuery = afterAt;
        _searchUsers(afterAt);
        return;
      }
    }

    // No active mention
    if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
        _mentionResults = [];
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _showMentionSuggestions = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(20)
          .get();

      final results = snapshot.docs
          .map((doc) => doc.data())
          .where((user) {
            final username = (user['username'] ?? '').toString().toLowerCase();
            final fullName = (user['fullName'] ?? '').toString().toLowerCase();
            return username.contains(query.toLowerCase()) ||
                fullName.contains(query.toLowerCase());
          })
          .take(5)
          .toList();

      setState(() {
        _mentionResults = results;
        _showMentionSuggestions = results.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Mention search error: $e');
    }
  }

  void _insertMention(String username) {
    final text = textController.text;
    final cursorPos = textController.selection.baseOffset;
    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(cursorPos);
    final newText = '$before@$username $after';
    textController.text = newText;
    textController.selection = TextSelection.collapsed(
      offset: _mentionStartIndex + username.length + 2, // +2 for @ and space
    );
    setState(() {
      _showMentionSuggestions = false;
      _mentionResults = [];
    });
  }

  Future<void> _pickMedia(String mediaType) async {
    try {
      if (mediaType == 'audio' || mediaType == 'document') {
        SnackbarUtil.info('Info', '$mediaType upload coming soon');
        return;
      }

      // Open Cloudinary Upload Widget directly
      final url = await CloudinaryWidgetService.uploadFile(
        mediaType: mediaType,
      );

      if (url != null) {
        setState(() {
          selectedMediaUrls.add(url);
          selectedMediaType = mediaType;
        });
        SnackbarUtil.success('Ready', '$mediaType attached to post');
      } else {
        SnackbarUtil.info('Cancelled', 'No media selected');
      }
    } catch (e) {
      SnackbarUtil.error('Error', 'Failed to upload $mediaType: $e');
    }
  }

  void _removeMedia(int index) {
    setState(() {
      selectedMediaUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Share Insight",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: postController.isLoading.value
                    ? null
                    : () async {
                        final text = textController.text.trim();
                        if (text.isNotEmpty || selectedMediaUrls.isNotEmpty) {
                          // Extract Mentions (@user)
                          final mentions = RegExp(r'@(\w+)')
                              .allMatches(text)
                              .map((m) => m.group(1)!)
                              .toList();

                          // Extract Hashtags (#tag)
                          final tags = RegExp(r'#(\w+)')
                              .allMatches(text)
                              .map((m) => m.group(1)!)
                              .toList();

                          // Media is already uploaded, just pass the URLs
                          if (selectedMediaUrls.isNotEmpty) {
                            await postController.uploadPost(
                              text,
                              selectedMediaUrls,
                              tags: tags,
                              mentions: mentions,
                              mediaType: selectedMediaType,
                            );
                          } else {
                            await postController.uploadPost(
                              text,
                              null,
                              tags: tags,
                              mentions: mentions,
                            );
                          }
                          textController.clear();
                          setState(() => selectedMediaUrls.clear());
                        } else {
                          SnackbarUtil.error(
                            "Empty",
                            "Please write something or add media.",
                          );
                        }
                      },
                child: postController.isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text("Post", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "What's your professional insight today? Use @ to tag people",
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),

                  // Selected media preview
                  if (selectedMediaUrls.isNotEmpty) ...[
                    const Text(
                      'Uploaded Media:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: selectedMediaUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                _getMediaIcon(selectedMediaType),
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$selectedMediaType ${index + 1} uploaded ✓',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeMedia(index),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Upload progress indicator
                  Obx(
                    () => postController.uploadProgress.value > 0
                        ? Column(
                            children: [
                              LinearProgressIndicator(
                                value: postController.uploadProgress.value,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(postController.uploadProgress.value * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Media action buttons
                  const Text(
                    'Add Media:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildMediaButton(
                        icon: Icons.image,
                        label: 'Picture',
                        mediaType: 'image',
                      ),
                      _buildMediaButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        mediaType: 'video',
                      ),
                      _buildMediaButton(
                        icon: Icons.mic,
                        label: 'Audio',
                        mediaType: 'audio',
                      ),
                      _buildMediaButton(
                        icon: Icons.description,
                        label: 'Document',
                        mediaType: 'document',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // @mention suggestions overlay
          if (_showMentionSuggestions)
            Positioned(
              left: 20,
              right: 20,
              top: 120, // Below the text field area
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mentionResults.length,
                    itemBuilder: (context, index) {
                      final user = _mentionResults[index];
                      final username = user['username'] ?? 'user';
                      final fullName = user['fullName'] ?? 'User';
                      final profileImgUrl = user['profileImageUrl'];
                      final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primaryBlue,
                          backgroundImage: (profileImgUrl != null && profileImgUrl.toString().isNotEmpty)
                              ? NetworkImage(profileImgUrl)
                              : null,
                          child: (profileImgUrl == null || profileImgUrl.toString().isEmpty)
                              ? Text(initial,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14))
                              : null,
                        ),
                        title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('@$username', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        dense: true,
                        onTap: () => _insertMention(username),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required String mediaType,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _pickMedia(mediaType),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  IconData _getMediaIcon(String mediaType) {
    switch (mediaType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.mic;
      case 'document':
        return Icons.description;
      default:
        return Icons.attachment;
    }
  }
}
