import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_user.dart';

class AuthRepository {
  final GoogleSignIn _googleSignIn;

  AuthRepository({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: [
              'email',
              'profile',
              'https://www.googleapis.com/auth/drive.file',
            ],
          );

  Stream<AuthUser?> get user {
    return _googleSignIn.onCurrentUserChanged.map((
      GoogleSignInAccount? account,
    ) {
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
      debugPrint('AUTH: interactive Google sign-in started');
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('AUTH: interactive Google sign-in returned no account');
        return null;
      }

      debugPrint('AUTH: Google account returned: ${account.email}');

      return AuthUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl,
      );
    } on PlatformException catch (e, stackTrace) {
      debugPrint(
        'AUTH: Google PlatformException '
        'code=${e.code}, message=${e.message}, details=${e.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('AUTH: Google sign-in failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      debugPrint('AUTH: silent Google sign-in started');
      final account = await _googleSignIn.signInSilently();
      debugPrint('AUTH: silent Google sign-in account: ${account?.email}');
      return account;
    } catch (e, stackTrace) {
      debugPrint('AUTH: silent Google sign-in failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Revokes this app's Google access and removes the current account session.
  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
  }

  Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    return _googleSignIn.currentUser;
  }
}
