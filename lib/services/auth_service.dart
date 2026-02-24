import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../screens/auth/sign_in_screen.dart';
import 'package:flutter/foundation.dart';
import '../core/snackbar_util.dart';

/// ==========================================
/// FIREBASE AUTHENTICATION & DATABASE SERVICE
/// ==========================================
///
/// This service manages:
/// 1. User Registration (Firebase Auth + Firestore)
/// 2. User Sign-In (Firebase Auth + Profile Verification)
/// 3. User Sign-Out (Cleanup & Navigation)
/// 4. Atomic Transactions (Username reservation + Profile creation)
///
/// Key Concepts:
/// - Firebase Auth: Handles email/password authentication
/// - Cloud Firestore: Stores user profiles and social data
/// - Transactions: Ensure username is reserved BEFORE profile created
///   (If username taken, entire signup is rolled back - no orphaned users)
///
/// Database Collections Used:
/// - /users/{uid}          → User profile data
/// - /usernames/{username} → Global username registry (prevent duplicates)
///
/// Example Data Structure in Firestore:
///
/// users/user_123 {
///   uid: "user_123"
///   fullName: "John Doe"
///   username: "johndoe"
///   email: "john@example.com"
///   followers: ["user_456", "user_789"]  // UIDs who follow this user
///   following: ["user_456"]                // UIDs this user follows
///   createdAt: Timestamp(...)               // Server timestamp
/// }
///
/// usernames/johndoe {
///   uid: "user_123"
///   createdAt: Timestamp(...)
/// }
///
class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ==========================================
  /// USER REGISTRATION (Sign Up)
  /// ==========================================
  ///
  /// Creates a new user account with atomic transaction guarantee:
  /// 1. Firebase Auth creates user (email/password)
  /// 2. Firestore TRANSACTION begins:
  ///    a. Check if username is available
  ///    b. Reserve username in /usernames collection
  ///    c. Create user profile in /users collection
  /// 3. If ANY step fails, transaction rolls back (no partial data)
  ///
  /// Why transaction? Prevention against race conditions:
  /// Without transaction: User A & B could both reserve "johndoe"
  /// With transaction: Only first to complete step 2a succeeds
  ///
  /// Parameters:
  /// - [email]: User's email (from signup form)
  /// - [password]: User's password (stored securely by Firebase)
  /// - [name]: Display name (e.g., "John Doe")
  /// - [username]: Unique handle (e.g., "johndoe")
  ///
  /// Returns:
  /// - Firebase User object if signup succeeds
  /// - null if signup fails (and shows error message to user)
  ///
  /// Possible Errors:
  /// - EMAIL_ALREADY_IN_USE: Email already registered
  /// - WEAK_PASSWORD: Password < 6 characters
  /// - INVALID_EMAIL: Email format incorrect
  /// - USERNAME_TAKEN: Someone else has this username
  /// - PERMISSION_DENIED: Firestore rules need updating
  /// - NETWORK_ERROR: No internet connection
  ///
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    User? user;
    try {
      debugPrint(
        'SignUp: Starting registration for email=$email, username=$username',
      );

      /// ==========================================
      /// STEP 1: Create Firebase Auth User
      /// ==========================================
      /// Firebase handles email/password validation:
      /// - Checks if email already registered
      /// - Validates password strength (min 6 chars)
      /// - Creates user with secure password hashing
      /// - Returns User object with auto-generated UID
      ///
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;

      if (user == null) {
        SnackbarUtil.error('Registration Failed', 'Unable to create account.');
        return null;
      }

      /// ==========================================
      /// STEP 2: Prepare Firestore References
      /// ==========================================
      /// These references will be used in the transaction below.
      /// We don't write yet - just prepare the references.
      ///
      final userRef = _db.collection('users').doc(user.uid);
      final usernameRef = _db.collection('usernames').doc(username);

      try {
        /// ==========================================
        /// STEP 3: ATOMIC TRANSACTION
        /// ==========================================
        ///
        /// Transaction Example Flow:
        /// ├─ Check: Does /usernames/johndoe exist? NO ✓
        /// ├─ Action: Create /usernames/johndoe { uid: "user123" }
        /// ├─ Action: Create /users/user123 { username: "johndoe", ... }
        /// └─ Commit: Both writes succeed
        ///
        /// If username WAS taken:
        /// ├─ Check: Does /usernames/johndoe exist? YES ✗
        /// ├─ Throw: USERNAME_TAKEN exception
        /// └─ Rollback: Both writes are cancelled
        ///
        /// Why transaction? Without it:
        /// 1. User A: Check username "johndoe" - available
        /// 2. User B: Check username "johndoe" - available  ⚠️ RACE CONDITION!
        /// 3. Both create accounts with "johndoe" ❌ Duplicates!
        ///
        /// With transaction: Database locks "johndoe" until one wins
        ///
        await _db.runTransaction((txn) async {
          // Check if username already taken (prevents duplicates)
          final usernameSnap = await txn.get(usernameRef);
          if (usernameSnap.exists) {
            throw Exception('USERNAME_TAKEN');
          }

          /// ==========================================
          /// Reserve the Username
          /// ==========================================
          /// Document ID: username (lowercase, unique)
          /// Purpose: Global registry to prevent duplicate usernames
          ///
          txn.set(usernameRef, {
            'uid': user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          /// ==========================================
          /// Create User Profile
          /// ==========================================
          /// Document ID: user.uid (from Firebase Auth)
          /// Initial fields: Basic profile + empty social arrays
          /// Empty arrays: followers/following start empty (user has no connections yet)
          ///
          txn.set(userRef, {
            'uid': user.uid,
            'fullName': name,
            'username': username,
            'email': email,
            'followers': <String>[], // Will be populated when others follow
            'following':
                <String>[], // Will be populated when user follows others
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        debugPrint(
          'SignUp: Transaction completed successfully for uid=${user.uid}',
        );
        return user;
      } on FirebaseException catch (txnErr) {
        // Handle Firestore transaction errors
        debugPrint('SignUp: Firestore transaction error - ${txnErr.code}');
        String reason = 'A server error occurred. Please try again.';

        // Custom error handling for username availability
        if ((txnErr.message ?? '').contains('USERNAME_TAKEN') ||
            txnErr.toString().contains('USERNAME_TAKEN')) {
          reason = 'This username is already taken. Try another one.';
          SnackbarUtil.warning('Username Taken', reason);
        } else if (txnErr.code.contains('permission-denied')) {
          reason =
              'Insufficient permissions. Check Firestore rules or contact support.';
          SnackbarUtil.error(
            'Registration Failed',
            reason,
            duration: const Duration(seconds: 5),
          );
        } else if (txnErr.code.contains('unavailable')) {
          reason = 'Service unavailable. Please try again later.';
          SnackbarUtil.error(
            'Registration Failed',
            reason,
            duration: const Duration(seconds: 5),
          );
        } else if (txnErr.code.contains('deadline-exceeded') ||
            txnErr.code.contains('timeout')) {
          reason = 'Request timed out. Check your connection and try again.';
          SnackbarUtil.error(
            'Registration Failed',
            reason,
            duration: const Duration(seconds: 5),
          );
        } else {
          final msg = txnErr.message?.toString() ?? '';
          if (msg.isNotEmpty) reason = msg;
          SnackbarUtil.error(
            'Registration Failed',
            reason,
            duration: const Duration(seconds: 5),
          );
        }

        /// ==========================================
        /// CLEANUP: Delete Firebase Auth User
        /// ==========================================
        /// Transaction failed, so we need to clean up the Firebase Auth user
        /// we created earlier. Otherwise user is stuck in Auth but not in Firestore.
        ///
        try {
          await user.delete();
        } catch (delErr) {
          debugPrint(
            'SignUp: failed to delete auth user after txn error: $delErr',
          );
        }
        return null;
      } catch (txnErr) {
        // Catch general exceptions from transaction (including USERNAME_TAKEN)
        debugPrint('SignUp: Transaction exception - $txnErr');

        if (txnErr.toString().contains('USERNAME_TAKEN')) {
          SnackbarUtil.warning(
            'Username Taken',
            'This username is already claimed. Try another one.',
          );
        } else {
          SnackbarUtil.error(
            'Registration Failed',
            'Something went wrong during profile setup. Please try again.',
            duration: const Duration(seconds: 4),
          );
        }

        // Cleanup auth user since transaction failed
        try {
          await user.delete();
        } catch (delErr) {
          debugPrint(
            'SignUp: failed to delete auth user after txn error: $delErr',
          );
        }
        return null;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'SignUp: FirebaseAuthException - code=${e.code}, message=${e.message}',
      );
      String errorMsg = 'Registration failed';
      final code = e.code.toString().toLowerCase();
      if (code.contains('weak-password')) {
        errorMsg = 'Password is too weak (minimum 6 characters).';
      } else if (code.contains('email-already-in-use')) {
        errorMsg = 'Email is already registered.';
      } else if (code.contains('invalid-email')) {
        errorMsg = 'Email format is invalid.';
      } else {
        final msg = e.message?.toString() ?? '';
        if (msg.isNotEmpty) errorMsg = msg;
      }

      SnackbarUtil.error(
        'Registration Failed',
        errorMsg,
        duration: const Duration(seconds: 5),
      );

      // If auth user was created but FirebaseAuth error occurred, attempt cleanup
      if (user != null) {
        try {
          await user.delete();
        } catch (delErr) {
          debugPrint('SignUp: failed to delete auth user after error: $delErr');
        }
      }

      return null;
    }
  }

  /// ==========================================
  /// USER SIGN-IN
  /// ==========================================
  ///
  /// Authenticates user and verifies profile exists in Firestore.
  ///
  /// Security Check: After Firebase Auth succeeds, we verify the user profile
  /// exists in Firestore. This prevents orphaned users (e.g., if admin deleted
  /// the profile but auth user still exists).
  ///
  /// Flow:
  /// 1. Firebase Auth validates email/password
  /// 2. If valid, get user object
  /// 3. Verify user document exists in /users collection
  /// 4. If missing, sign out user (indicates deleted account)
  /// 5. Return user object if both checks pass
  ///
  /// Why verify profile? Edge cases:
  /// - Admin deleted user profile but auth user still exists
  /// - Data inconsistency between Auth and Firestore
  /// - Prevents access to incomplete accounts
  ///
  /// Returns:
  /// - Firebase User object if sign-in succeeds AND profile exists
  /// - null if email/password wrong OR profile missing
  ///
  /// Possible Errors:
  /// - USER_NOT_FOUND: No account with this email
  /// - WRONG_PASSWORD: Incorrect password
  /// - INVALID_EMAIL: Email format incorrect
  /// - USER_DISABLED: Account disabled by admin
  /// - TOO_MANY_REQUESTS: Rate limited (too many failed attempts)
  /// - PERMISSION_DENIED: Firestore rules need updating
  ///
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      /// ==========================================
      /// STEP 1: Firebase Auth Validation
      /// ==========================================
      /// Firebase Auth validates email/password combination
      /// Returns User object if credentials are correct
      ///
      final credentials = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credentials.user;

      /// ==========================================
      /// STEP 2: Verify Profile Exists in Firestore
      /// ==========================================
      /// Security check: After Auth succeeds, verify the user profile
      /// document exists in /users collection.
      ///
      /// Why this check?
      /// - Prevents orphaned users (Auth user with no Firestore profile)
      /// - Indicates different data inconsistencies
      /// - Could happen if admin deletes profile but Auth user remains
      ///
      /// Edge Case Example:
      /// User A signs up → Auth user created + Firestore profile created
      /// Admin manually deletes Firestore profile
      /// User A tries to sign in → Auth succeeds BUT profile missing
      /// Result: Sign out user to prevent incomplete session
      ///
      if (user != null) {
        try {
          final doc = await _db.collection('users').doc(user.uid).get();
          if (!doc.exists) {
            /// Profile missing - sign out user
            await _auth.signOut();
            SnackbarUtil.warning(
              'Account Removed',
              'This account has been removed. Contact support if this is a mistake.',
              duration: const Duration(seconds: 5),
            );
            return null;
          }
        } catch (e) {
          /// If we can't read Firestore (permissions/network), sign out to avoid
          /// allowing an incomplete session. Better to require re-login than let
          /// incomplete state continue.
          await _auth.signOut();
          debugPrint('SignIn: failed to verify profile existence - $e');
          SnackbarUtil.error(
            'Sign In Failed',
            'Unable to verify account. Check your connection and try again.',
            duration: const Duration(seconds: 4),
          );
          return null;
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('SignIn: FirebaseAuthException - ${e.code}');
      String message = 'Sign in failed. Please try again.';
      final code = e.code.toString().toLowerCase();
      if (code.contains('user-not-found')) {
        message = 'No account found for that email.';
      } else if (code.contains('wrong-password')) {
        message = 'Incorrect password.';
      } else if (code.contains('invalid-email')) {
        message = 'Invalid email address.';
      } else if (code.contains('user-disabled')) {
        message = 'This account has been disabled.';
      } else if (code.contains('too-many-requests')) {
        message = 'Too many failed attempts. Please try again later.';
      }

      SnackbarUtil.error(
        'Sign In Failed',
        message,
        duration: const Duration(seconds: 4),
      );
      return null;
    } catch (e) {
      debugPrint('SignIn: General exception - $e');
      if (e is FirebaseException) {
        final code = e.code.toString().toLowerCase();
        String reason = 'A server error occurred. Please try again.';
        if (code.contains('permission-denied')) {
          reason =
              'Insufficient permissions. Check Firestore rules or contact support.';
        } else if (code.contains('unavailable')) {
          reason = 'Service unavailable. Please try again later.';
        } else if (code.contains('deadline-exceeded') ||
            code.contains('timeout')) {
          reason = 'Request timed out. Check your connection and try again.';
        } else {
          final msg = e.message?.toString() ?? '';
          if (msg.isNotEmpty) reason = msg;
        }
        SnackbarUtil.error(
          'Sign In Failed',
          reason,
          duration: const Duration(seconds: 4),
        );
        return null;
      }

      SnackbarUtil.error(
        'Sign In Failed',
        'Something went wrong. Please try again.',
        duration: const Duration(seconds: 4),
      );
      return null;
    }
  }

  /// ==========================================
  /// USER SIGN-OUT
  /// ==========================================
  ///
  /// Signs out the current user from Firebase Auth and navigates to SignInScreen.
  ///
  /// Why navigate?
  /// - If user is on authenticated screens and we just call signOut(), they'll see
  ///   placeholder data or loading screens
  /// - Redirecting ensures proper UI state and prevents accessing protected screens
  ///
  /// Flow:
  /// 1. Call _auth.signOut() (clears auth session)
  /// 2. Navigate to SignInScreen (Get.offAll replaces all routes)
  ///
  /// Possible Errors:
  /// - Navigation might fail if context is invalid (caught and logged)
  ///
  Future<void> signOut() async {
    /// Clear Firebase Auth session
    await _auth.signOut();

    /// Navigate to SignInScreen, removing all other routes from stack.
    /// This prevents user from going "back" into the authenticated part of app.
    /// Example route stack:
    /// Before: [SplashScreen, HomeScreen, ProfileScreen]
    /// After: [SignInScreen]
    ///
    try {
      Get.offAll(() => SignInScreen());
    } catch (e) {
      debugPrint('SignOut: navigation failed - $e');
    }
  }

  /// ==========================================
  /// PASSWORD RESET
  /// ==========================================
  ///
  /// Sends a password reset email to the provided address.
  ///
  /// Possible Errors:
  /// - user-not-found: Email not registered
  /// - invalid-email: Email format incorrect
  /// - network-request-failed: Connection issues
  ///
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint('PasswordReset: FirebaseAuthException - ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('PasswordReset: General exception - $e');
      rethrow;
    }
  }
}
