# Post UID Migration Script

## Issue
Posts were missing the `uid` field, which prevents the feed from displaying posts from other users correctly. The `getFollowingPostsStream()` method in the FeedController uses `where('uid', whereIn: following)` to filter posts.

## Solution
This script adds the `uid` field to all existing posts by matching the post's `username` with users in the database.

## How to Run

1. **From your Flutter app root directory**, run:
   ```bash
   dart scripts/fix_post_uids.dart
   ```

2. **Make sure your Firebase is initialized** with the proper credentials in your app.

3. The script will:
   - Find all posts missing or empty `uid` field
   - Match each post's username with users in the database
   - Update the post with the correct `uid`
   - Print a summary of how many posts were updated

## Notes
- This is a one-time operation
- Safe to run multiple times (won't overwrite existing uids)
- Requires Firebase Admin SDK or proper Firestore authentication
- If a post's username doesn't match any user, it will be skipped with a warning

## Alternative: Manual Fix in Firebase Console
If you prefer, you can also manually update posts in the Firebase Console:
1. Go to Firestore Database → posts collection
2. Find posts without a `uid` field
3. Edit each document and add the `uid` field with the post author's uid value
