import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth_service.dart';
import 'login.dart';
import 'inventory_dashboard.dart';
import 'product_management_dashboard.dart';
import 'cashier_order_screen.dart';
import 'analytics_service.dart';
import 'analytics_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => AnalyticsService()),
      ],
      child: const AntigravityApp(),
    ),
  );
}

class AntigravityApp extends StatelessWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toppings POS',
      theme: ThemeData(
        primaryColor: const Color(0xFF8B1D1D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B1D1D),
        ).copyWith(background: Colors.white),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B1D1D),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B1D1D),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.currentUser == null) {
          return const LoginScreen();
        }

        if (authService.userRole == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authService.userRole == 'Cashier') {
          return const CashierHomePage();
        } else if (authService.userRole == 'Manager/Owner' ||
            authService.userRole == 'Manager') {
          return const ManagerDashboardPage();
        }

        return const Scaffold(
          body: Center(child: Text('Invalid user role assigned.')),
        );
      },
    );
  }
}

class CashierHomePage extends StatelessWidget {
  const CashierHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F4),
      appBar: AppBar(
        title: const Text('Cashier — Tap to Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: const CashierOrderScreen(),
    );
  }
}

class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome, Manager!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1D1D),
              ),
            ),
            const SizedBox(height: 48.0),
            SizedBox(
              height: 60.0,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InventoryDashboard(),
                    ),
                  );
                },
                icon: const Icon(Icons.inventory),
                label: const Text(
                  'INVENTORY',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            SizedBox(
              height: 60.0,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductManagementDashboard(),
                    ),
                  );
                },
                icon: const Icon(Icons.rice_bowl),
                label: const Text(
                  'PRODUCTS',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            SizedBox(
              height: 60.0,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider.value(
                        value: context.read<AnalyticsService>(),
                        child: const AnalyticsDashboard(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text(
                  'REPORTS ANALYTICS',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
