import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_controller.dart';

import '../core/app_theme.dart';
import '../screens/main/profile_page.dart';
import '../screens/main/search_results_page.dart';


/// Utility to build styled RichText that makes @mentions tappable and blue.
class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const MentionText({super.key, required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? const TextStyle(fontSize: 16);
    final spans = _buildSpans(context, text, style);
    return RichText(text: TextSpan(children: spans));
  }

  static List<InlineSpan> _buildSpans(
      BuildContext context, String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    // Match @username OR #hashtag (alphanumeric + underscores)
    // Group 1: username (from @...)
    // Group 2: hashtag (from #...)
    final regex = RegExp(r'(@\w+)|(#\w+)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedString = match.group(0)!;
      final isMention = matchedString.startsWith('@');
      final isHashtag = matchedString.startsWith('#');

      if (isMention) {
        final username = matchedString.substring(1);
        spans.add(TextSpan(
          text: matchedString,
          style: baseStyle.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _navigateToUserProfile(username);
            },
        ));
      } else if (isHashtag) {
        final tag = matchedString.substring(1);
        spans.add(TextSpan(
          text: matchedString,
          style: baseStyle.copyWith(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // TODO: Navigate to search results with tag
               _navigateToSearch(context, tag);
            },
        ));
      }

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    // If no matches found, return the plain text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
  
  static void _navigateToSearch(BuildContext context, String tag) {
    Get.to(() => SearchResultsPage(initialQuery: tag));
  }

  static void _navigateToUserProfile(String username) async {
    try {
      final profileController = Get.find<ProfileController>();
      await profileController.loadUserProfileByUsername(username);
      final user = profileController.selectedUser.value;
      if (user != null) {
        Get.to(() => ProfilePage(userId: user.uid));
      }
    } catch (e) {
      debugPrint('Could not find user @$username: $e');
    }
  }
}
