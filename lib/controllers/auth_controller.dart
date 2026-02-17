import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/snackbar_util.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db =
      FirebaseFirestore.instance; // Instance for database queries

  var user = Rxn<User>();
  var isLoading = false.obs;

  @override
  void onInit() {
    user.bindStream(FirebaseAuth.instance.authStateChanges());
    super.onInit();
  }

  /// Registers user after verifying that the username is unique
  Future<void> register(
    String email,
    String password,
    String name,
    String username,
  ) async {
    isLoading.value = true;

    try {
      // Validate input
      if (email.isEmpty ||
          password.isEmpty ||
          name.isEmpty ||
          username.isEmpty) {
        isLoading.value = false;
        SnackbarUtil.error("Validation Error", "All fields are required");
        return;
      }

      // Proceed with registration - username uniqueness is enforced
      // by the transaction in AuthService (no race condition)
      debugPrint("Starting registration for username='$username'...");
      var result = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        username: username,
      );

      if (result != null) {
        // Verify that the user document was created in Firestore
        debugPrint("Auth successful for UID: ${result.uid}");

        // Wait a moment for Firestore to sync
        await Future.delayed(const Duration(milliseconds: 500));

        final userDoc = await _db.collection('users').doc(result.uid).get();
        if (userDoc.exists) {
          debugPrint("User document verified in Firestore");
          isLoading.value = false;
          SnackbarUtil.success(
            "Success",
            "Account created! Complete your profile to get started.",
          );
          // Navigate after successful registration
          await Future.delayed(const Duration(milliseconds: 1000));
          Get.offAllNamed('/MainLayout');
        } else {
          debugPrint(
            "ERROR: User document NOT created in Firestore after signup!",
          );
          isLoading.value = false;
          SnackbarUtil.warning(
            "Warning",
            "Account created but profile setup incomplete. Try creating your profile manually.",
          );
        }
      } else {
        isLoading.value = false;
        SnackbarUtil.error(
          "Registration Failed",
          "Could not create account. Please try again.",
        );
      }
    } catch (e) {
      isLoading.value = false;
      debugPrint("Registration error: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
      SnackbarUtil.error(
        "Registration Failed",
        "Something went wrong. Please try again.",
        duration: const Duration(seconds: 5),
      );
    }
  }
}
