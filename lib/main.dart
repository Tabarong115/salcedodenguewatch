import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/app_state.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/admin_service.dart';
import 'screens/public/public_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/staff/staff_dashboard.dart';
import 'screens/auth/account_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with credentials from config
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  await EasyLocalization.ensureInitialized();
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fil')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const SalcedoDengueWatch(),
    ),
  );
}

class SalcedoDengueWatch extends StatelessWidget {
  const SalcedoDengueWatch({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => DataService()),
        Provider(create: (_) => AdminService()),
      ],
      child: MaterialApp(
        title: 'Salcedo Dengue Watch',
        builder: (context, child) => SafeArea(
          child: child ?? const SizedBox.shrink(),
        ),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            displayMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    if (authService.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }
    
    // Show error message if authentication failed during initialization
    if (authService.errorMessage != null && !authService.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Authentication Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  authService.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Clear error and retry
                    authService.signOut();
                  },
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!authService.isAuthenticated) {
      return const PublicDashboard();
    }

    if (authService.isPasswordRecovery) {
      return const AccountSetupScreen(isPasswordReset: true);
    }

    if (authService.currentUser?.requiresPasswordSetup == true) {
      return const AccountSetupScreen();
    }
    
    // Route based on role
    final userRole = authService.currentUser?.role;
    
    if (userRole == 'admin') {
      return const AdminDashboard();
    }
    
    // All staff roles use the StaffDashboard
    if (userRole == 'rhu_staff' || 
        userRole == 'encoder' || 
        userRole == 'bhw' || 
        userRole == 'bsi' || 
        userRole == 'hospital_staff') {
      return const StaffDashboard();
    }
    
    // Fallback to public dashboard for unknown roles
    return const PublicDashboard();
  }
}
