// ─────────────────────────────────────────────────────────────────────────────
// FILE: role_guard.dart
// PURPOSE: Role-based access control for pages and UI elements
//
// ROLE HIERARCHY (from Symfony):
//   ROLE_ADMIN    → everything (owner)
//   ROLE_MANAGER  → stats, CRUD products/categories/suppliers/users/stock
//   ROLE_TELLER   → sales, validate orders
//   ROLE_WAITER   → create orders, view products/categories
//
// HOW IT WORKS:
//   1. After login, the role is saved in SharedPreferences (kUserRole)
//   2. RoleGuard reads it and decides what to show
//   3. Sidebar only shows links the user can access
//   4. Pages show an "Access denied" screen if user navigates directly
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppRole — all possible roles (must match Symfony ROLE_ constants)
// ─────────────────────────────────────────────────────────────────────────────
class AppRole {
  // Raw role strings stored in SharedPreferences after JWT decode
  static const String admin   = 'ROLE_ADMIN';
  static const String manager = 'ROLE_MANAGER';
  static const String teller  = 'ROLE_TELLER';
  static const String waiter  = 'ROLE_WAITER';

  // Human-readable labels (stored as kUserRole after login)
  static const String adminLabel   = 'Administrateur';
  static const String managerLabel = 'Manager';
  static const String tellerLabel  = 'Caissier';
  static const String waiterLabel  = 'Serveur';

  // Convert label → raw role string
  static String fromLabel(String label) {
    switch (label) {
      case adminLabel:   return admin;
      case managerLabel: return manager;
      case tellerLabel:  return teller;
      case waiterLabel:  return waiter;
      default:           return waiter; // default to lowest permission
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleService — reads the current user role and checks permissions
// ─────────────────────────────────────────────────────────────────────────────
class RoleService {
  // Cache so we don't hit SharedPreferences on every check
  static String _cachedRole = '';

  // ── Get current role (raw ROLE_XXX string) ────────────────────────────────
  static Future<String> getCurrentRole() async {
    if (_cachedRole.isNotEmpty) return _cachedRole;
    final prefs = await SharedPreferences.getInstance();
    // kUserRole stores the label ("Administrateur") — convert to raw role
    final label = prefs.getString(kUserRole) ?? '';
    _cachedRole = AppRole.fromLabel(label);
    return _cachedRole;
  }

  // ── Clear cache on logout ────────────────────────────────────────────────
  static void clearCache() => _cachedRole = '';

  // ── Permission checks ─────────────────────────────────────────────────────

  // Admin only — company management, full control
  static Future<bool> isAdmin() async {
    return await getCurrentRole() == AppRole.admin;
  }

  // Manager or above — statistics, CRUD catalog, users
  static Future<bool> isManagerOrAbove() async {
    final r = await getCurrentRole();
    return r == AppRole.admin || r == AppRole.manager;
  }

  // Teller or above — sales, validate orders
  static Future<bool> isTellerOrAbove() async {
    final r = await getCurrentRole();
    return r == AppRole.admin || r == AppRole.manager || r == AppRole.teller;
  }

  // All authenticated users
  static Future<bool> isWaiterOrAbove() async {
    return true; // all logged-in users have at least ROLE_WAITER
  }

  // ── Page access rules ─────────────────────────────────────────────────────
  // Returns true if the current user can access the given route

  static Future<bool> canAccess(String route) async {
    final r = await getCurrentRole();
    switch (route) {
      // Admin only
      case '/company':
        return r == AppRole.admin;

      // Manager + Admin
      case '/dashboard':
      case '/product':
      case '/category':
      case '/supplier':
      case '/users':
      case '/stock':
        return r == AppRole.admin || r == AppRole.manager;

      // Teller + Manager + Admin
      case '/sale':
        return r == AppRole.admin || r == AppRole.manager || r == AppRole.teller;

      // All roles
      case '/order':
        return true;

      default:
        return true;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleGuard — widget that wraps a page with permission check
//
// Usage:
//   RoleGuard(
//     route: '/dashboard',
//     child: DashboardPage(),
//   )
//
// If the user doesn't have permission → shows AccessDeniedPage
// ─────────────────────────────────────────────────────────────────────────────
class RoleGuard extends StatefulWidget {
  final String route;  // the route to check (e.g. '/dashboard')
  final Widget child;  // the page to show if allowed

  const RoleGuard({super.key, required this.route, required this.child});

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool? _allowed; // null = loading, true = allowed, false = denied

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final allowed = await RoleService.canAccess(widget.route);
    if (!mounted) return;
    setState(() => _allowed = allowed);
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permissions
    if (_allowed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Allowed — show the page
    if (_allowed!) return widget.child;
    // Denied — show access denied screen
    return const AccessDeniedPage();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AccessDeniedPage — shown when user tries to access a restricted page
// ─────────────────────────────────────────────────────────────────────────────
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: Color(0xFFD32F2F), size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              "Accès refusé",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Vous n'avez pas les permissions\nnécessaires pour accéder à cette page.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF757575), fontSize: 14),
            ),
            const SizedBox(height: 32),
            // Go back button
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text("Retour"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RoleVisible — shows/hides a widget based on role
//
// Usage:
//   RoleVisible(
//     allowedRoles: [AppRole.admin, AppRole.manager],
//     child: ElevatedButton(...),
//   )
// ─────────────────────────────────────────────────────────────────────────────
class RoleVisible extends StatefulWidget {
  final List<String> allowedRoles; // list of roles that can see this widget
  final Widget child;
  final Widget? fallback; // shown if not allowed (default: SizedBox.shrink)

  const RoleVisible({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  @override
  State<RoleVisible> createState() => _RoleVisibleState();
}

class _RoleVisibleState extends State<RoleVisible> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final role = await RoleService.getCurrentRole();
    if (!mounted) return;
    setState(() => _visible = widget.allowedRoles.contains(role));
  }

  @override
  Widget build(BuildContext context) {
    if (_visible) return widget.child;
    return widget.fallback ?? const SizedBox.shrink();
  }
}