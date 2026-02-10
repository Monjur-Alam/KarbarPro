import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth service
  final authService = AuthService();
  await authService.initialize();
  
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  
  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amar Dokan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue.shade700,
          secondary: Colors.purple.shade600,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      // Check if user is already signed in
      home: authService.isSignedIn 
          ? const DashboardScreen() 
          : const LoginScreen(),
    );
  }
}
