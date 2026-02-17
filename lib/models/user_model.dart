import 'package:cloud_firestore/cloud_firestore.dart';
import 'experience_model.dart';
import 'education_model.dart';
import 'project_model.dart';

/// ==========================================
/// USER DATA MODEL
/// ==========================================
///
/// This class represents a complete user profile as stored in Firestore.
/// Location in Firestore: /users/{userId}
///
/// DOCUMENT SCHEMA:
/// ------------------------------------------
/// uid: String             - The unique Firebase Auth ID (Primary Key)
/// fullName: String        - User's display name
/// username: String        - Unique @handle (reserved in /usernames collection)
/// email: String           - Login email (read-only in profile)
/// bio: String?            - Optional self-description
/// headline: String?       - Professional title (e.g. "Software Engineer")
/// location: String?       - Geographical location
/// profileImageUrl: String?- Cloudinary URL for avatar
/// bannerImageUrl: String? - Cloudinary URL for cover photo
///
/// SOCIAL FEATURES (Using UID Arrays):
/// ------------------------------------------
/// followers: List<String> - UIDs of users who follow this user
/// following: List<String> - UIDs of users this user is following
/// connections: List<String>- UIDs of mutual connections
///
/// PROFESSIONAL SECTIONS:
/// ------------------------------------------
/// skills: List<String>    - Array of skill strings
/// experiences: List<Map>  - Nested objects (see Experience class)
/// education: List<Map>    - Nested objects (see Education class)
/// projects: List<Map>     - Nested objects (see Project class)
///
/// DESIGN RATIONALE:
/// ------------------------------------------
/// 1. Denormalization: We store arrays of UIDs for followers instead of subcollections
///    to allow for faster "is following" checks and simple count logic.
/// 2. Atomic Updates: When following, we use FieldValue.arrayUnion to ensure
///    concurrency safety without needing complex background triggers.
/// 3. One-to-Many: Professional data (Experience/Projects) is nested inside
///     the user document for high-speed profile loading in a single read.
///
class UserModel {
  final String uid; // Firebase Auth UID (immutable, unique)
  final String fullName; // Display name
  final String username; // Unique handle (e.g., @johndoe)
  final String email; // Used for login
  final String? bio; // Optional biography
  final String? headline; // Professional headline/title
  final String? location; // City/region
  final String? profileImageUrl; // Avatar image URL
  final String? bannerImageUrl; // Cover image URL

  /// ==========================================
  /// SOCIAL GRAPH FIELDS (Arrays of UIDs only)
  /// ==========================================
  ///
  /// Why store UIDs and not full user objects?
  /// 1. Storage: Storing 1000 followers with full user data = lots of duplication
  /// 2. Updates: If John changes profile pic, need to update all followers' data = expensive
  /// 3. Consistency: Single source of truth for each user's profile
  /// 4. Performance: Checking if user A follows user B is O(1) with uid array
  ///
  /// Example:
  /// followers: ["user_456", "user_789"]
  /// → When showing follower list, fetch /users/user_456 separately
  /// → Get fresh data without duplication
  ///

  /// List of UIDs of users following this user.
  /// When user A follows user B, we do:
  /// 1. Add A to B's followers array
  /// 2. Add B to A's following array
  ///
  /// Example Flow:
  /// users/john → { followers: [] }
  /// users/jane → { following: [] }
  ///
  /// Jane clicks "Follow John":
  /// users/john → { followers: ["jane_uid"] }          // Added
  /// users/jane → { following: ["john_uid"] }          // Added
  final List<String> followers;

  /// List of UIDs this user is following.
  /// Maintained in sync with the followed user's followers array.
  /// Used to generate the user's personalized feed.
  final List<String> following;

  /// List of UIDs of mutual connections (pending/accepted).
  /// "Connections" = stricter than follows (requires mutual acceptance).
  /// Note: Currently not actively used, but available for future features
  /// like connection requests or LinkedIn-style connections.
  final List<String> connections;

  /// Professional skills (e.g., ["Flutter", "Dart", "Firebase", "UI/UX"])
  /// Used for:
  /// - Profile display
  /// - Skill-based search/filtering
  /// - Professional recommendations
  final List<String> skills;

  /// Work experience history (array of Experience objects).
  /// Each object contains: title, company, dates, description, isCurrent.
  /// Serialized as list of maps in Firestore, converted to Experience objects here.
  final List<Experience> experiences;

  /// Education history (array of Education objects).
  final List<Education> education;

  /// Portfolio projects (array of Project objects).
  /// Each object contains: title, description, technologies, urls.
  /// Serialized as list of maps in Firestore, converted to Project objects here.
  final List<Project> projects;

  /// ==========================================
  /// CONSTRUCTOR
  /// ==========================================
  UserModel({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    this.bio,
    this.headline,
    this.location,
    this.profileImageUrl,
    this.bannerImageUrl,
    this.followers = const [],
    this.following = const [],
    this.connections = const [],
    this.skills = const [],
    this.experiences = const [],
    this.education = const [],
    this.projects = const [],
  });

  /// ==========================================
  /// CONVERTER: Firestore Document → UserModel
  /// ==========================================
  ///
  /// Used when reading from Firestore:
  /// final doc = await db.collection('users').doc(uid).get();
  /// final user = UserModel.fromMap(doc.data()!);
  ///
  /// This factory method:
  /// 1. Safely extracts each field from Firestore map
  /// 2. Handles missing fields with sensible defaults
  /// 3. Converts nested objects (experiences, projects)
  /// 4. Casts dynamic lists to proper types
  /// 5. Returns a guaranteed non-null UserModel
  ///
  /// Why safe defaults?
  /// - Users might lack optional fields (e.g., no bio set yet)
  /// - Historical data might be missing new fields
  /// - Prevents crashes from missing data
  ///
  /// Example:
  /// Firestore data: { uid: "123", fullName: "John" }  (missing email!)
  /// Result: email defaults to ''
  /// → No null pointer exception
  ///
  /// Nested Object Conversion:
  /// experiences: [
  ///   { title: "Engineer", company: "Google", ... }
  /// ]
  /// → Converted to: [Experience.fromMap({...})]
  /// → So we can call user.experiences[0].title safely
  ///
  factory UserModel.fromMap(Map<String, dynamic> map) {
    /// Convert experience maps to Experience objects
    final experiences =
        (map['experiences'] as List?)
            ?.map((e) => Experience.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    /// Convert project maps to Project objects
    final projects =
        (map['projects'] as List?)
            ?.map((p) => Project.fromMap(p as Map<String, dynamic>))
            .toList() ??
        [];

    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? 'Professional',
      username: map['username'] ?? 'user',
      email: map['email'] ?? '',
      bio: map['bio'], // null if missing
      headline: map['headline'], // null if missing
      location: map['location'], // null if missing
      profileImageUrl: map['profileImageUrl'], // null if missing
      bannerImageUrl: map['bannerImageUrl'], // null if missing
      /// UID arrays: Cast from dynamic list, default to empty list
      /// Why List<String>.from()? Dart needs explicit type conversion.
      /// Firestore returns List<dynamic>, we need List<String>.
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      connections: List<String>.from(map['connections'] ?? []),
      skills: List<String>.from(map['skills'] ?? []),

      /// Nested objects already converted above
      experiences: experiences,
      education: (map['education'] as List?)
              ?.map((e) => Education.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      projects: projects,
    );
  }

  /// ==========================================
  /// CONVERTER: UserModel → Firestore Document
  /// ==========================================
  ///
  /// Used when saving/updating profile:
  /// final newData = user.toMap();
  /// await db.collection('users').doc(user.uid).update(newData);
  ///
  /// This method:
  /// 1. Converts all UserModel fields back to map format
  /// 2. Converts Experience/Project objects back to maps
  /// 3. Preserves null values (for optional fields)
  /// 4. Returns a structure that Firestore can store
  ///
  /// Example:
  /// UserModel(
  ///   uid: "123",
  ///   fullName: "John",
  ///   experiences: [Experience(...)]
  /// )
  /// ↓ toMap() ↓
  /// {
  ///   uid: "123",
  ///   fullName: "John",
  ///   experiences: [{ ... }]  (converted back to map)
  /// }
  ///
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'username': username,
      'email': email,
      'bio': bio,
      'headline': headline,
      'location': location,
      'profileImageUrl': profileImageUrl,
      'bannerImageUrl': bannerImageUrl,
      'followers': followers,
      'following': following,
      'connections': connections,
      'skills': skills,
      'experiences': experiences.map((e) => e.toMap()).toList(),
      'education': education.map((e) => e.toMap()).toList(),
      'projects': projects.map((p) => p.toMap()).toList(),
    };
  }
}
