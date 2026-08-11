import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'core/themes/app_theme.dart';
import 'core/settings/app_settings_cubit.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'core/services/background_sync_helper.dart';
import 'core/services/sync_service.dart';
import 'core/services/google_drive_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/database/database_helper.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/dashboard/presentation/bloc/home_bloc.dart';
import 'features/customers/data/customer_repository.dart';
import 'features/customers/presentation/bloc/customer_bloc.dart';
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/sales/data/sales_repository.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/reports/data/report_repository.dart';
import 'features/reports/presentation/bloc/report_bloc.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
  final customerRepository = CustomerRepository(dbHelper: dbHelper);
  final salesRepository = SalesRepository(dbHelper: dbHelper);
  final inventoryRepository = InventoryRepository(dbHelper: dbHelper);
  final reportRepository = ReportRepository(dbHelper: dbHelper);

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
    customerRepository: customerRepository,
    salesRepository: salesRepository,
    inventoryRepository: inventoryRepository,
    reportRepository: reportRepository,
    connectivityService: connectivityService,
    dbHelper: dbHelper,
    driveService: driveService,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final SyncService syncService;
  final DashboardRepository dashboardRepository;
  final CustomerRepository customerRepository;
  final SalesRepository salesRepository;
  final InventoryRepository inventoryRepository;
  final ReportRepository reportRepository;
  final ConnectivityService connectivityService;
  final DatabaseHelper dbHelper;
  final GoogleDriveService driveService;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.syncService,
    required this.dashboardRepository,
    required this.customerRepository,
    required this.salesRepository,
    required this.inventoryRepository,
    required this.reportRepository,
    required this.connectivityService,
    required this.dbHelper,
    required this.driveService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: syncService),
        RepositoryProvider.value(value: dashboardRepository),
        RepositoryProvider.value(value: customerRepository),
        RepositoryProvider.value(value: salesRepository),
        RepositoryProvider.value(value: inventoryRepository),
        RepositoryProvider.value(value: reportRepository),
        RepositoryProvider.value(value: connectivityService),
        RepositoryProvider.value(value: dbHelper),
        RepositoryProvider.value(value: driveService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: authRepository,
              syncService: syncService,
              dbHelper: dbHelper,
            )..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) => HomeBloc(
              repository: dashboardRepository,
              syncService: syncService,
            ),
          ),
          BlocProvider(
            create: (context) => CustomerBloc(repository: customerRepository)..add(LoadCustomers()),
          ),
          BlocProvider(
            create: (context) => SalesBloc(
              repository: salesRepository,
              syncService: syncService,
            )..add(LoadSalesInitialData()),
          ),
          BlocProvider(
            create: (context) => InventoryBloc(
              repository: inventoryRepository,
              syncService: syncService,
            )..add(LoadProducts()),
          ),
          BlocProvider(
            create: (context) => ReportBloc(repository: reportRepository),
          ),
          BlocProvider(
            create: (context) => AppSettingsCubit(),
          ),
        ],

        child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
          buildWhen: (prev, curr) =>
              prev.locale != curr.locale || prev.themeMode != curr.themeMode,
          builder: (context, settingsState) {
            return MaterialApp(
              title: 'Karbar Pro',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settingsState.flutterThemeMode,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('bn', 'BD'),
                Locale('en', 'US'),
              ],
              locale: settingsState.locale,
              home: const AppView(),
              navigatorObservers: [routeObserver],
            );
          },
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

