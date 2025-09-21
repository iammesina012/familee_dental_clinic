import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projects/features/activity_log/controller/login_activity_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedEmailKey = 'remembered_email';

  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    // Normalize email to avoid case-related bypasses
    final provided = email.trim();
    final providedLower = provided.toLowerCase();

    // Map to Firebase Auth email via Firestore (try lowercase first)
    QuerySnapshot<Map<String, dynamic>> userQuery = await _firestore
        .collection('user_roles')
        .where('email', isEqualTo: providedLower)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      // Fallback to original case if data wasn't normalized
      userQuery = await _firestore
          .collection('user_roles')
          .where('email', isEqualTo: provided)
          .limit(1)
          .get();
    }

    String loginEmail = providedLower; // default to lowercase for sign-in

    if (userQuery.docs.isNotEmpty) {
      final userData = userQuery.docs.first.data();
      final firebaseAuthEmail = userData['firebaseAuthEmail'] as String?;
      if (firebaseAuthEmail != null && firebaseAuthEmail.isNotEmpty) {
        loginEmail = firebaseAuthEmail.toLowerCase();
      }
    }

    // First, attempt authentication so wrong creds show the correct error
    final userCred = await _auth.signInWithEmailAndPassword(
        email: loginEmail, password: password);

    // After successful auth, enforce our Firestore isActive flag
    QuerySnapshot<Map<String, dynamic>> statusSnap = await _firestore
        .collection('user_roles')
        .where('firebaseAuthEmail', isEqualTo: loginEmail)
        .limit(1)
        .get();

    if (statusSnap.docs.isEmpty) {
      // Fallback to original case if needed
      statusSnap = await _firestore
          .collection('user_roles')
          .where('firebaseAuthEmail', isEqualTo: provided)
          .limit(1)
          .get();
    }

    if (statusSnap.docs.isNotEmpty) {
      final isActive =
          statusSnap.docs.first.data()['isActive'] as bool? ?? true;
      if (!isActive) {
        // Prevent session if deactivated
        try {
          await _auth.signOut();
        } catch (_) {}
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'This account is inactive. Please contact an admin.',
        );
      }
    }

    // Save remember me preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(
          _rememberedEmailKey, email); // Store original email for display
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  /// Login with username instead of email
  Future<void> loginWithUsername({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    // Look up email from username in Firestore
    final userQuery = await _firestore
        .collection('user_roles')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Username not found',
      );
    }

    final userData = userQuery.docs.first.data();
    final email = userData['email'] as String?;
    final firebaseAuthEmail = userData['firebaseAuthEmail'] as String?;

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'No email associated with this username',
      );
    }

    // Use the Firebase Auth email for actual login (lowercased)
    final loginEmail = (firebaseAuthEmail ?? email).toLowerCase();

    // Block inactive users
    QuerySnapshot<Map<String, dynamic>> statusSnap = await _firestore
        .collection('user_roles')
        .where('firebaseAuthEmail', isEqualTo: loginEmail)
        .limit(1)
        .get();

    if (statusSnap.docs.isEmpty) {
      // Fallback to original-case if present in DB that way
      statusSnap = await _firestore
          .collection('user_roles')
          .where('firebaseAuthEmail', isEqualTo: (firebaseAuthEmail ?? email))
          .limit(1)
          .get();
    }

    if (statusSnap.docs.isNotEmpty) {
      final isActive =
          statusSnap.docs.first.data()['isActive'] as bool? ?? true;
      if (!isActive) {
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'This account is inactive. Please contact an admin.',
        );
      }
    }

    // Already signed in above; continue

    // Save remember me preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey);
  }

  Future<bool> isUserLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      final rememberMe = await isRememberMeEnabled();
      return rememberMe;
    }
    return false;
  }

  Future<void> logout() async {
    // Log logout activity before signing out
    await LoginActivityController().logLogout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_rememberedEmailKey);
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
