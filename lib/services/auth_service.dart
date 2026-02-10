import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;
  UserModel? _userModel;

  // Getters
  GoogleSignInAccount? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isSignedIn => _currentUser != null;

  // Initialize and check for existing session
  Future<void> initialize() async {
    try {
      // Listen to sign-in state changes
      _googleSignIn.onCurrentUserChanged.listen((account) {
        _currentUser = account;
        if (account != null) {
          _userModel = UserModel(
            id: account.id,
            displayName: account.displayName ?? 'User',
            email: account.email,
            photoUrl: account.photoUrl,
          );
        } else {
          _userModel = null;
        }
      });

      // Try to sign in silently
      await _googleSignIn.signInSilently();
    } catch (error) {
      print('Error initializing auth: $error');
    }
  }

  // Sign in with Google
  Future<UserModel?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        _userModel = UserModel(
          id: account.id,
          displayName: account.displayName ?? 'User',
          email: account.email,
          photoUrl: account.photoUrl,
        );

        // Save sign-in state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isSignedIn', true);
        await prefs.setString('userEmail', account.email);

        return _userModel;
      }
      return null;
    } catch (error) {
      print('Error signing in: $error');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _userModel = null;

      // Clear sign-in state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isSignedIn');
      await prefs.remove('userEmail');
    } catch (error) {
      print('Error signing out: $error');
      rethrow;
    }
  }

  // Get authentication headers for Google APIs
  Future<Map<String, String>> getAuthHeaders() async {
    if (_currentUser == null) {
      throw Exception('User not signed in');
    }

    final auth = await _currentUser!.authentication;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  // Get access token for Google APIs
  Future<String?> getAccessToken() async {
    if (_currentUser == null) {
      return null;
    }

    final auth = await _currentUser!.authentication;
    return auth.accessToken;
  }
}
