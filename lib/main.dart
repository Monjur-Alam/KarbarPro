import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../core/themes/app_theme.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../core/services/background_sync_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authRepository = AuthRepository();

  // Initialize Background Sync in the background
  // to avoid blocking app startup (splash screen freeze)
  BackgroundSyncHelper.initialize().then((_) {
    BackgroundSyncHelper.registerPeriodicSync();
  }).catchError((e) {
    debugPrint('Background sync initialization failed: $e');
  });
  
  runApp(MyApp(authRepository: authRepository));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;

  const MyApp({super.key, required this.authRepository});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        create: (context) => AuthBloc(authRepository: authRepository)..add(AuthCheckRequested()),
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
          body: SizedBox.expand(),
        );
      },
    );
  }
}
