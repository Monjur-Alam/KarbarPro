import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../core/themes/app_theme.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../core/services/background_sync_helper.dart';
import '../core/services/sync_service.dart';
import '../core/services/google_drive_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/database/database_helper.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/presentation/bloc/home_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/drive.file'],
  );
  
  final authRepository = AuthRepository(googleSignIn: googleSignIn);
  final dbHelper = DatabaseHelper();
  final driveService = GoogleDriveService(googleSignIn);
  final connectivityService = ConnectivityService();
  final syncService = SyncService(driveService, dbHelper, connectivityService);
  final dashboardRepository = DashboardRepository(dbHelper);

  // Initialize Background Sync
  BackgroundSyncHelper.initialize().then((_) {
    BackgroundSyncHelper.registerPeriodicSync();
  }).catchError((e) {
    debugPrint('Background sync initialization failed: $e');
  });
  
  runApp(MyApp(
    authRepository: authRepository,
    syncService: syncService,
    dashboardRepository: dashboardRepository,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final SyncService syncService;
  final DashboardRepository dashboardRepository;

  const MyApp({
    super.key, 
    required this.authRepository,
    required this.syncService,
    required this.dashboardRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: syncService),
        RepositoryProvider.value(value: dashboardRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepository)..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) => HomeBloc(
              repository: dashboardRepository,
              syncService: syncService,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Amar Dokan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('bn', 'BD'), // Bengali (Bangladesh)
            Locale('en', 'US'), // English (US)
          ],
          locale: const Locale('bn', 'BD'), // Default to Bengali
          home: const AppView(),
        ),
      ),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const DashboardScreen();
        } else if (state is AuthUnauthenticated || state is AuthFailure) {
          return const LoginScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

