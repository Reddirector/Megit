import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  // Web Client ID from Firebase Console (used for robust ID token exchange)
  static const String _clientId = '290283449789-jp4hog1ghgkedj7c80vcujeo78igm48p.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
     clientId: _clientId, // Uncomment and update after user provides the Web Client ID
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/youtube.readonly',
    ],
  );

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      debugPrint('[GoogleAuthService] SignIn error: $error');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('[GoogleAuthService] SignOut error: $error');
    }
  }

  static Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }
}
