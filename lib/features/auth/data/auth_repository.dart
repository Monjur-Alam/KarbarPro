import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_user.dart';

class AuthRepository {
  final GoogleSignIn _googleSignIn;

  AuthRepository({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: [
            'email',
            'profile',
            'https://www.googleapis.com/auth/drive.file',
          ],
        );

  Stream<AuthUser?> get user {
    return _googleSignIn.onCurrentUserChanged.map((GoogleSignInAccount? account) {
      if (account == null) return null;
      return AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl,
      );
    });
  }

  Future<AuthUser?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      
      return AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
  
  Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    return _googleSignIn.currentUser;
  }
}
