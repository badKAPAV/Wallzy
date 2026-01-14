import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:wallzy/core/models/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add the MethodChannel here to access native methods for clearing local data.
  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  UserModel? _user;
  bool _isLoading = false;

  // Flag to track if we are waiting for the initial auth state to be determined.
  bool _isAuthCheckLoading = true;
  bool get isAuthLoading => _isAuthCheckLoading;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  // Flag to check if the user is new (i.e., no Firestore doc).
  bool _isNewUser = false;
  bool get isNewUser => _isNewUser;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    final prefs = await SharedPreferences.getInstance();

    if (firebaseUser == null) {
      _user = null;
      _isNewUser = false;
      await prefs.remove('last_user_id');
      _isAuthCheckLoading = false;
      notifyListeners();
      return;
    }

    // User is logged in
    try {
      // 1. FAST PATH: Check cache with timeout
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      try {
        userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {}

      // If doc exists, parse it.
      if (userDoc != null && userDoc.exists) {
        _user = UserModel.fromMap(firebaseUser.uid, userDoc.data()!);
        _isNewUser = false;
      } else {
        // Doc might not exist in cache. Try server.
      }
    } catch (e) {
      debugPrint("Error fetching user profile from cache: $e");
    }

    // Attempt Server Fetch to confirm user existence if local was checking
    if (_user == null) {
      try {
        final serverDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get(const GetOptions(source: Source.server));

        if (serverDoc.exists) {
          _user = UserModel.fromMap(firebaseUser.uid, serverDoc.data()!);
          _isNewUser = false;
        } else {
          // No doc on server either -> New User
          _isNewUser = true;
          // Temporarily create a dummy user model so the app doesn't crash on null checks
          _user = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email,
            name: firebaseUser.displayName ?? '',
            photoURL: firebaseUser.photoURL,
          );
        }
      } catch (e) {
        // Offline and no cache -> Assume existing but offline?
        // Or new? Safer to populate basic info for now.
        _user = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          name: firebaseUser.displayName ?? '',
          photoURL: firebaseUser.photoURL,
        );
      }
    }

    // Save ID for background utility
    await prefs.setString('last_user_id', firebaseUser.uid);

    // Unblock UI immediately
    _isAuthCheckLoading = false;
    notifyListeners();
  }

  // --- MAGIC LINK AUTH ---

  Future<void> sendMagicLink(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final acs = ActionCodeSettings(
        url: 'https://wallet-wallzy.web.app/login',
        handleCodeInApp: true,
        iOSBundleId: 'com.kapav.wallzy',
        androidPackageName: 'com.kapav.wallzy',
        androidInstallApp: true,
        androidMinimumVersion: '21',
      );

      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);

      // Save the email locally so we don't need to ask the user for it again
      // if they open the link on the same device.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailLink', email);
    } catch (e) {
      debugPrint("Error sending magic link: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailLink(String email, String link) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_auth.isSignInWithEmailLink(link)) {
        await _auth.signInWithEmailLink(email: email, emailLink: link);
        // _onAuthStateChanged will handle the rest
      } else {
        throw Exception('Invalid Magic Link');
      }
    } catch (e) {
      debugPrint("Error signing in with magic link: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- GOOGLE SIGN IN ---

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User aborted the sign-in
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      await _auth.signInWithCredential(credential);
      // _onAuthStateChanged will handle the rest
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- REGISTRATION COMPLETION ---

  Future<void> completeRegistration({
    required String name,
    required DateTime? dob,
    File? imageFile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('No authenticated user found');

      String? photoURL;
      if (imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(firebaseUser.uid);
        await storageRef.putFile(imageFile);
        photoURL = await storageRef.getDownloadURL();
      } else {
        // If no new image, use existing (e.g. from Google) or null
        photoURL = firebaseUser.photoURL;
      }

      // Update Firebase Auth Profile
      await firebaseUser.updateDisplayName(name);
      if (photoURL != null) {
        await firebaseUser.updatePhotoURL(photoURL);
      }

      // Create Firestore Document
      final newUser = UserModel(
        uid: firebaseUser.uid,
        name: name,
        email: firebaseUser.email,
        photoURL: photoURL,
        userCreatedAt: DateTime.now(),
        isProUser: false,
        dob: dob,
        hasPassword: false,
      );

      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toMap());

      // Update local state
      _user = newUser;
      _isNewUser = false; // Registration complete!
    } catch (e) {
      debugPrint("Error completing registration: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({
    required String name,
    File? imageFile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) throw Exception('Not logged in');

      String? photoURL;
      if (imageFile != null) {
        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(firebaseUser.uid);
        await storageRef.putFile(imageFile);
        photoURL = await storageRef.getDownloadURL();
      }

      // Update Firebase Auth profile
      await firebaseUser.updateDisplayName(name);
      if (photoURL != null) {
        await firebaseUser.updatePhotoURL(photoURL);
      }

      // Update Firestore document
      final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
      final updateData = <String, dynamic>{'name': name};
      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }
      await userDocRef.update(updateData);

      // Refresh user data locally
      await _onAuthStateChanged(firebaseUser);

      // Clear image cache to ensure the new profile picture is loaded
      if (photoURL != null) {
        await DefaultCacheManager().emptyCache();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if the user has a password set.
  // We prioritize the Firestore-based flag for accuracy (distinguishing from Magic Link).
  bool get hasPassword {
    return _user?.hasPassword ?? false;
  }

  Future<void> setPassword(String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user found');

      await user.updatePassword(password);

      // Update Firestore flag
      await _firestore.collection('users').doc(user.uid).update({
        'hasPassword': true,
      });

      // Refresh local user state
      _user = _user?.copyWith(hasPassword: true);

      notifyListeners();
    } catch (e) {
      debugPrint("Error setting password: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Restored for backward compatibility until refactor is complete
  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.email == null) {
        throw Exception('User not found or email is null');
      }

      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(cred);

      // Update password
      await firebaseUser.updatePassword(newPassword);

      // Ensure Firestore flag is set
      await _firestore.collection('users').doc(firebaseUser.uid).update({
        'hasPassword': true,
      });

      // Refresh local user state
      _user = _user?.copyWith(hasPassword: true);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Deprecated: Use Magic Link or Google Sign In
  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If sign in is successful and the flag isn't set yet (legacy user), update it.
      if (_user != null && !_user!.hasPassword) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({'hasPassword': true});
        _user = _user!.copyWith(hasPassword: true);
      }
    } catch (e) {
      debugPrint("Error signing in: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Deprecated: Use Magic Link or Google Sign In
  Future<void> signUp(String name, String email, String password) async {
    // Placeholder to satisfy linter
    notifyListeners();
  }

  Future<void> signOut() async {
    // Clear local and cached data before signing out to ensure user privacy.
    try {
      // 1. Clear pending SMS transactions from SharedPreferences on the native side.
      await _platform.invokeMethod('removeAllPendingSmsTransactions');

      // 2. Terminate the Firestore instance to cancel pending writes and close network connections.
      // This is a recommended step before clearing persistence.
      await _firestore.terminate();

      // 3. Clear the local cache of Firestore data.
      await _firestore.clearPersistence();

      // 4. Clear the image cache.
      await DefaultCacheManager().emptyCache();

      // Clear local prefs for magic link
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emailLink');
    } catch (e) {
      // Log errors but don't block sign-out. The user should always be able to sign out.
      debugPrint("Error clearing data on sign out: $e");
    }

    // 4. Sign out from Firebase Auth.
    await _auth.signOut();
    _isNewUser = false;
    _user = null;
    notifyListeners();
  }
}
