import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to add missing 'uid' field to existing posts
/// Run this once to fix all posts that don't have a uid field
Future<void> main() async {
  // Initialize Firebase (requires proper config)
  await Firebase.initializeApp();

  final db = FirebaseFirestore.instance;

  print("Starting post uid migration...");

  try {
    // Get all posts that have a name field but might be missing uid
    final postsSnapshot = await db.collection('posts').get();

    int updated = 0;
    int skipped = 0;

    for (var postDoc in postsSnapshot.docs) {
      final data = postDoc.data();

      // Check if uid is already set
      if (data['uid'] != null && data['uid'].toString().isNotEmpty) {
        print("Post ${postDoc.id} already has uid: ${data['uid']}");
        skipped++;
        continue;
      }

      // If uid is missing but username exists, we need to find the user
      final username = data['username'] ?? '';

      if (username.isNotEmpty) {
        // Try to find the user by username to get their uid
        try {
          final userQuery = await db
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final uid = userQuery.docs.first['uid'];
            await db.collection('posts').doc(postDoc.id).update({'uid': uid});
            print("Updated post ${postDoc.id}: Added uid=$uid");
            updated++;
          } else {
            print(
              "Warning: Could not find user with username=$username for post ${postDoc.id}",
            );
            skipped++;
          }
        } catch (e) {
          print("Error querying user for post ${postDoc.id}: $e");
          skipped++;
        }
      } else {
        print("Warning: Post ${postDoc.id} has no username or name");
        skipped++;
      }
    }

    print("\nMigration complete!");
    print("Updated: $updated posts");
    print("Skipped: $skipped posts");
  } catch (e) {
    print("Migration failed: $e");
    rethrow;
  }
}
