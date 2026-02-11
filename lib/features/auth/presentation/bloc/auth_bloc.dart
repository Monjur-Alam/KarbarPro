import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:amar_dokan/core/services/sync_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

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

  AuthBloc({
    required AuthRepository authRepository,
    required SyncService syncService,
  })  : _authRepository = authRepository,
        _syncService = syncService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Note: Don't emit AuthLoading if you want to avoid a white splash
    // but here we are already in AppView's BlocBuilder.
    try {
      // 1. Try to get the current user immediately if already available
      final currentUser = await _authRepository.getCurrentGoogleUser();
      
      if (currentUser != null) {
        emit(AuthAuthenticated(AuthUser(
          id: currentUser.id,
          email: currentUser.email,
          displayName: currentUser.displayName ?? '',
          photoUrl: currentUser.photoUrl,
        )));
        _syncService.checkAndRestoreFromDrive(); // Check for restore on startup/check
        return;
      }

      // 2. Try to restore previous session silently
      // We use a timeout to ensure we don't hang the app start
      final user = await _authRepository.signIn()
          .timeout(const Duration(seconds: 3))
          .catchError((_) => null);

      if (user != null) {
        emit(AuthAuthenticated(user));
        _syncService.checkAndRestoreFromDrive(); // Check for restore on session restore
      } else {
        emit(AuthUnauthenticated());
      }
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
      if (user != null) {
        emit(AuthAuthenticated(user));
        _syncService.checkAndRestoreFromDrive(); // Check for restore on login
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }
}
