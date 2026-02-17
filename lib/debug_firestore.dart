import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> debugCheckPosts() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    print('DEBUG: No user logged in');
    return;
  }
  
  print('DEBUG: Checking posts for user: $uid');
  final snapshot = await FirebaseFirestore.instance
      .collection('posts')
      .where('uid', isEqualTo: uid)
      .limit(5)
      .get();
      
  print('DEBUG: Found ${snapshot.docs.length} posts');
  for (var doc in snapshot.docs) {
    final data = doc.data();
    print('POST ID: ${doc.id}');
    print(' - Name: ${data['name']}');
    print(' - Username: ${data['username']}');
    print(' - ProfileImageUrl: "${data['profileImageUrl']}"');
    print(' - ProfileInitial: "${data['profileInitial']}"');
    print('-------------------------');
  }
}
