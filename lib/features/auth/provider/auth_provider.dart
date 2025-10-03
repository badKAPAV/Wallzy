import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/core/models/user.dart';

class AuthProvider with ChangeNotifier{
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add the MethodChannel here to access native methods for clearing local data.
  static const _platform = MethodChannel('com.example.wallzy/sms');

  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    final prefs = await SharedPreferences.getInstance();
    if(firebaseUser == null){
      _user = null;
      // Clear the stored user ID on logout for the background service.
      await prefs.remove('last_user_id');
    } else {
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (userDoc.exists) {
        _user = UserModel.fromMap(firebaseUser.uid, userDoc.data()!);
      } else {
        // Fallback for users that might not have a firestore document
        _user = UserModel(uid: firebaseUser.uid, email: firebaseUser.email, name: firebaseUser.displayName ?? '', photoURL: firebaseUser.photoURL);
      }
      // Save the current user's ID for the background service to use.
      await prefs.setString('last_user_id', firebaseUser.uid);
    }
    notifyListeners();
  }

  Future<void> signUp(String name, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name in Firebase Auth
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        name: name,
        email: email,
      );
      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());

      // _onAuthStateChanged will be called automatically and update the state
    } on FirebaseAuthException {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({required String name, File? imageFile}) async {
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
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
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
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    } catch (e) {
      // Log errors but don't block sign-out. The user should always be able to sign out.
      debugPrint("Error clearing data on sign out: $e");
    }

    // 4. Sign out from Firebase Auth.
    await _auth.signOut();
    // _onAuthStateChanged will handle clearing the in-memory user object.
  }
}