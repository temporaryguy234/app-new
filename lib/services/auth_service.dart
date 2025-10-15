import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        await _updateLastLogin(result.user!.uid);
        return await _getUserFromFirestore(result.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Register with email and password
  Future<UserModel?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Create user document in Firestore
        final userModel = UserModel(
          id: result.user!.uid,
          email: email,
          name: email.split('@')[0], // Use email prefix as name
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(result.user!.uid).set(userModel.toMap());
        
        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Registrierung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      
      if (result.user != null) {
        // Check if user exists in Firestore
        UserModel? userModel = await _getUserFromFirestore(result.user!.uid);
        
        if (userModel == null) {
          // Create new user
          userModel = UserModel(
            id: result.user!.uid,
            email: result.user!.email ?? '',
            name: result.user!.displayName,
            photoUrl: result.user!.photoURL,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          
          await _firestore.collection('users').doc(result.user!.uid).set(userModel.toMap());
        } else {
          await _updateLastLogin(result.user!.uid);
        }
        
        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Google-Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Sign in with Facebook
  Future<UserModel?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      
      if (result.status == LoginStatus.success) {
        final OAuthCredential facebookAuthCredential = 
            FacebookAuthProvider.credential(result.accessToken!.token);
        
        final UserCredential userCredential = 
            await _auth.signInWithCredential(facebookAuthCredential);
        
        if (userCredential.user != null) {
          // Check if user exists in Firestore
          UserModel? userModel = await _getUserFromFirestore(userCredential.user!.uid);
          
          if (userModel == null) {
            // Create new user
            userModel = UserModel(
              id: userCredential.user!.uid,
              email: userCredential.user!.email ?? '',
              name: userCredential.user!.displayName,
              photoUrl: userCredential.user!.photoURL,
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
            );
            
            await _firestore.collection('users').doc(userCredential.user!.uid).set(userModel.toMap());
          } else {
            await _updateLastLogin(userCredential.user!.uid);
          }
          
          return userModel;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Facebook-Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Sign in with Apple (iOS only)
  Future<UserModel?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential result = await _auth.signInWithCredential(oauthCredential);
      
      if (result.user != null) {
        // Check if user exists in Firestore
        UserModel? userModel = await _getUserFromFirestore(result.user!.uid);
        
        if (userModel == null) {
          // Create new user
          final fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
          userModel = UserModel(
            id: result.user!.uid,
            email: result.user!.email ?? credential.email ?? '',
            name: fullName.isNotEmpty ? fullName : null,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
          );
          
          await _firestore.collection('users').doc(result.user!.uid).set(userModel.toMap());
        } else {
          await _updateLastLogin(result.user!.uid);
        }
        
        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Apple-Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Automatic sign in (tries Google/Apple first, then anonymous)
  Future<UserModel?> signInAutomatically() async {
    try {
      // 1. Try Google Sign-In first (silent)
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          return await signInWithGoogle();
        }
      } catch (e) {
        // Google sign-in failed, continue to Apple
      }

      // 2. Try Apple Sign-In (if on iOS)
      try {
        return await signInWithApple();
      } catch (e) {
        // Apple sign-in failed, continue to anonymous
      }

      // 3. Fallback to anonymous sign-in
      return await signInAnonymously();
    } catch (e) {
      throw Exception('Automatische Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Sign in anonymously (fallback only)
  Future<UserModel?> signInAnonymously() async {
    try {
      final UserCredential result = await _auth.signInAnonymously();
      
      if (result.user != null) {
        // Create anonymous user in Firestore
        final userModel = UserModel(
          id: result.user!.uid,
          email: 'anonymous@linku.app',
          name: 'Anonymous User',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(result.user!.uid).set(userModel.toMap());
        return userModel;
      }
      return null;
    } catch (e) {
      throw Exception('Anonyme Anmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Abmeldung fehlgeschlagen: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Passwort-Reset fehlgeschlagen: ${e.toString()}');
    }
  }

  // Get user from Firestore
  Future<UserModel?> _getUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update last login
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignore error
    }
  }
}
