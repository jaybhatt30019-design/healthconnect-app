// lib/core/services/social_auth_service.dart
// Shared Google + Apple sign in logic
// Used by login, parent signup, caregiver signup screens

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';

enum SocialAuthResult {
  success,
  cancelled,
  userNotFound, // login only — no Firestore doc
  error,
}

class SocialAuthResponse {
  final SocialAuthResult result;
  final String? uid;
  final String? displayName;
  final String? email;
  final String? role; // null if new user
  final String? errorMessage;

  const SocialAuthResponse({
    required this.result,
    this.uid,
    this.displayName,
    this.email,
    this.role,
    this.errorMessage,
  });
}

class SocialAuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // ── Google Sign In ──────────────────────────────
  Future<SocialAuthResponse> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();

      // User cancelled picker
      if (googleUser == null) {
        return const SocialAuthResponse(
            result: SocialAuthResult.cancelled);
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred =
          await _auth.signInWithCredential(credential);
      final user = userCred.user!;

      // Check if Firestore doc exists
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return SocialAuthResponse(
        result: SocialAuthResult.success,
        uid: user.uid,
        displayName: user.displayName ??
            googleUser.displayName ??
            '',
        email: user.email ?? googleUser.email,
        // null if new user, role string if existing
       role: doc.exists ? (doc.data()?['role'] as String?) : null,
      );
    } catch (e) {
      debugPrint('[SocialAuth] Google error: $e');
      return SocialAuthResponse(
        result: SocialAuthResult.error,
        errorMessage:
            'Google sign in failed. Please try again.',
      );
    }
  }

  // ── Apple Sign In ───────────────────────────────
  Future<SocialAuthResponse> signInWithApple() async {
    try {
      final appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCred =
          await _auth.signInWithCredential(credential);
      final user = userCred.user!;

      // Apple only gives name on first sign in
      final givenName =
          appleCredential.givenName ?? '';
      final familyName =
          appleCredential.familyName ?? '';
      final fullName =
          '$givenName $familyName'.trim();

      // Check if Firestore doc exists
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return SocialAuthResponse(
        result: SocialAuthResult.success,
        uid: user.uid,
        displayName: fullName.isNotEmpty
            ? fullName
            : user.displayName ?? '',
        email: user.email ??
            appleCredential.email ??
            '',
       role: doc.exists ? (doc.data()?['role'] as String?) : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code ==
          AuthorizationErrorCode.canceled) {
        return const SocialAuthResponse(
            result: SocialAuthResult.cancelled);
      }
      debugPrint('[SocialAuth] Apple error: $e');
      return SocialAuthResponse(
        result: SocialAuthResult.error,
        errorMessage:
            'Apple sign in failed. Please try again.',
      );
    } catch (e) {
      debugPrint('[SocialAuth] Apple error: $e');
      return SocialAuthResponse(
        result: SocialAuthResult.error,
        errorMessage:
            'Apple sign in failed. Please try again.',
      );
    }
  }

  // ── Create Firestore user doc ───────────────────
  // Called after social sign in on signup screens
  Future<void> createUserDoc({
    required String uid,
    required String name,
    required String email,
    required String role,
    Map<String, dynamic> extra = const {},
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.now(),
      ...extra,
    }, SetOptions(merge: true));
  }

  // ── Sign out ─────────────────────────────────────
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}