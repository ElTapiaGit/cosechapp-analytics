import 'package:cosecha_app/data/models/harvest_model.dart';
import 'package:cosecha_app/logic/providers/projection_provider.dart';
import 'package:cosecha_app/logic/providers/quarterly_dashboard_provider.dart';
import 'package:cosecha_app/logic/providers/custom_report_provider.dart';
import 'package:cosecha_app/logic/providers/stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // Para fechas en español
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/services/supabase_service.dart';
import 'package:cosecha_app/core/services/storage_service.dart';
import 'package:cosecha_app/logic/providers/harvest_provider.dart';
import 'package:cosecha_app/logic/providers/import_harvest_provider.dart';
import 'logic/providers/auth_provider.dart';
import 'ui/screens/login_screen.dart';
import 'ui/layout/main_layout.dart';
import 'ui/screens/harvest_detail_screen.dart';
import 'ui/screens/reports/production_report_screen.dart';
import 'ui/screens/reports/programmer_report_screen.dart';
import 'ui/screens/reports/quarterly_dashboard_view.dart';
import 'ui/screens/reports/custom_report_screen.dart';
import 'ui/screens/reports/projection_reconciliation_screen.dart';
import 'ui/screens/reports/quarterly_production_report_screen.dart';
import 'ui/screens/web_upload/import_harvest_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await dotenv.load(fileName: ".env");

  // Inicializar Supabase
  await SupabaseService.initialize();
  // Iniciar Hive (Base de datos local)
  await StorageService.initialize();
  // Inicializar formato de fechas para español (Bolivia)
  await initializeDateFormatting('es_BO', null);

  runApp(const MyApp());
}

// Configuracion de Rutas
final _router = GoRouter(
  initialLocation: '/home', // Intentamos ir al home primero
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    
    // Si NO hay sesion y NO estamos yendo al login -> Mandar al Login
    if (session == null && state.uri.toString() != '/login') {
      return '/login';
    }

    // Si HAY sesion y estamos en login -> Mandar al Home
    if (session != null && state.uri.toString() == '/login') {
      return '/home';
    }

    return null; // No redirigir
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainLayout(),
    ),
    GoRoute(
      path: '/detail',
      builder: (context, state) {
        final harvest = state.extra as HarvestModel?;
        if (harvest != null) {
          return HarvestDetailScreen(harvest: harvest);
        }
        // Si se recarga con F5 y state.extra es null, redirigir a inicio o mostrar vista segura
        return const Scaffold(
          body: Center(
            child: Text('Sesión de detalle expirada. Por favor regrese a la lista.'),
          ),
        );
      },
    ),
    GoRoute(
      path: '/reports/production',
      builder: (context, state) => const ProductionReportScreen(),
    ),
    GoRoute(
      path: '/reports/programmer',
      builder: (context, state) => const ProgrammerReportScreen(),
    ),
    GoRoute(
      path: '/reports/quarterly',
      builder: (context, state) => const QuarterlyDashboardView(),
    ),
    GoRoute(
      path: '/reports/quarterly-production',
      builder: (context, state) => const QuarterlyProductionReportScreen(),
    ),
    GoRoute(
      path: '/reports/custom',
      builder: (context, state) => const CustomReportScreen(),
    ),
    GoRoute(
      path: '/reports/reconciliation',
      builder: (context, state) => const ProjectionReconciliationScreen(),
    ),
    GoRoute(
      path: '/reports/import',
      builder: (context, state) => ChangeNotifierProvider(
        create: (_) => ImportHarvestProvider(),
        child: const ImportHarvestScreen(),
      ),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inyectamos el AuthProvider para que toda la app lo vea
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HarvestProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),

        ChangeNotifierProvider(create: (_) => QuarterlyDashboardProvider()),
        ChangeNotifierProvider(create: (_) => ProjectionProvider()),
        ChangeNotifierProvider(create: (_) => CustomReportProvider()),
      ],
      child: MaterialApp.router(
        title: 'CosechApp',
        debugShowCheckedModeBanner: false,
        routerConfig: _router, // Usamos GoRouter
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
          Locale('es', 'BO'),
        ],
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.scaffoldBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryGreen,
            primary: AppColors.primaryGreen,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        ),
      ),
    );
  }
}
