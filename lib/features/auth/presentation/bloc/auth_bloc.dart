import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amar_dokan/core/services/sync_service.dart';
import 'package:amar_dokan/core/database/database_helper.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

const _kLastUserId = 'last_signed_in_user_id';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);
  @override
  List<Object> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SyncService _syncService;
  final DatabaseHelper _dbHelper;

  AuthBloc({
    required AuthRepository authRepository,
    required SyncService syncService,
    required DatabaseHelper dbHelper,
  }) : _authRepository = authRepository,
       _syncService = syncService,
       _dbHelper = dbHelper,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  /// Clears local DB + sync prefs when a DIFFERENT account signs in.
  Future<void> _clearIfAccountChanged(String newUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastUserId = prefs.getString(_kLastUserId);

    if (lastUserId != null && lastUserId != newUserId) {
      await _dbHelper.clearAllTables();
      await prefs.remove('sync_settings');
    }

    await prefs.setString(_kLastUserId, newUserId);
  }

  /// Wipes all local data and forgets the last user.
  /// Called on sign-out so the next login (any account) starts clean.
  Future<void> _clearLocalData() async {
    await _dbHelper.clearAllTables();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastUserId);
    await prefs.remove('sync_settings');
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final currentUser = await _authRepository.signInSilently();

      if (currentUser != null) {
        await _clearIfAccountChanged(currentUser.id);
        emit(
          AuthAuthenticated(
            AuthUser(
              id: currentUser.id,
              email: currentUser.email,
              displayName: currentUser.displayName ?? '',
              photoUrl: currentUser.photoUrl,
            ),
          ),
        );
        _syncService.checkAndRestoreFromDrive();
        return;
      }

      emit(AuthUnauthenticated());
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signIn();
      if (user == null) {
        debugPrint('AUTH: login cancelled or no Google account returned');
        emit(AuthUnauthenticated());
        return;
      }

      debugPrint('AUTH: preparing local account for ${user.email}');
      try {
        await _clearIfAccountChanged(user.id);
      } catch (e, stackTrace) {
        debugPrint('AUTH: local account preparation failed: $e');
        debugPrintStack(stackTrace: stackTrace);
        emit(
          AuthFailure(
            'Google sign-in succeeded, but local account setup failed: $e',
          ),
        );
        return;
      }

      debugPrint('AUTH: local account prepared; authenticating user');
      emit(AuthAuthenticated(user));
      _syncService.checkAndRestoreFromDrive();
    } catch (e, stackTrace) {
      debugPrint('AUTH: interactive login failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    await _clearLocalData(); // wipe data on every sign-out
    emit(AuthUnauthenticated());
  }
}
