// ─────────────────────────────────────────────────────────────────────────────
// FILE: main.dart
// PURPOSE: App entry point — sets up routing and global token expiry handler
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'core/api_service.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/dashboard_page.dart';

// Global navigator key — allows navigation from anywhere (including ApiService)
// without needing a BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Set up global token expiry handler ────────────────────────────────────
  // When ApiService receives a 401, it calls this function
  // which redirects to login from anywhere in the app
  ApiService().onTokenExpired = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  };

  runApp(const CaisseExpressApp());
}

class CaisseExpressApp extends StatelessWidget {
  const CaisseExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaisseExpress',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // navigatorKey allows ApiService to navigate without BuildContext
      navigatorKey: navigatorKey,
      home: const _SplashRouter(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SplashRouter — checks if JWT token exists on startup
// → token found AND not expired → Dashboard
// → no token → Login
// ─────────────────────────────────────────────────────────────────────────────
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kTokenKey);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            token != null ? const DashboardPage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: const Center(
                child: Text('R',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('CaisseExpress',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            const Text('Système de Caisse Rapide',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}