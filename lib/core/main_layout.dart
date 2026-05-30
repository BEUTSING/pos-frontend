// ─────────────────────────────────────────────────────────────────────────────
// FILE: main_layout.dart
// PURPOSE: Main app shell — vertical sidebar + horizontal topbar
//
// SIDEBAR contains:
//   - Company name (restaurant actif) at the top — NOT the app logo
//   - User name + real role badge
//   - All navigation links (all pages visible with scroll)
//   - Logout button at the bottom
//
// FIXES applied:
//   - Removed duplicate logo/app name from sidebar header
//   - Replaced with active restaurant name
//   - Fixed BOTTOM OVERFLOWED by wrapping sidebar in SingleChildScrollView
//   - All pages now visible in sidebar
//   - Real role displayed (from SharedPreferences)
//   - App renamed to CaisseExpress
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'role_guard.dart'; // role-based access control
import 'api_service.dart'; // needed to fetch company name

import '../features/dashboard/dashboard_page.dart';
import '../features/product/product_page.dart';
import '../features/category/category_page.dart';
import '../features/order/order_page.dart';
import '../features/sale/sale_page.dart';
import '../features/supplier/supplier_page.dart';
import '../features/users/users_page.dart';
import '../features/stock/stock_movement_page.dart';
import '../features/company/company_page.dart';
import '../features/auth/login_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainLayout — wraps every page with sidebar + topbar
// ─────────────────────────────────────────────────────────────────────────────
class MainLayout extends StatelessWidget {
  final Widget child;       // the page content shown on the right
  final String currentRoute; // highlights the active nav item

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: sidebar always visible
        // Mobile: sidebar hidden in a Drawer (hamburger menu)
        final isDesktop = constraints.maxWidth > 800;

        return Scaffold(
          backgroundColor: kBackground,

          // ── TOP APP BAR ──────────────────────────────────────────────────
          appBar: AppBar(
            automaticallyImplyLeading: !isDesktop,
            backgroundColor: kTopbarBg,
            toolbarHeight: 58,
            elevation: 0,

            // Hamburger menu on mobile
            leading: isDesktop
                ? null
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),

            // App logo + name in topbar
            title: Row(
              children: [
                // Logo image — replace 'R' with Image.asset when ready
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // TODO: replace with Image.asset('assets/logo.png')
                  child: const Center(
                    child: Text('C',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('CaisseExpress',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.3)),
                    Text('Gestion Restaurant',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),

            // Topbar right actions
            actions: [
              // Notification bell
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white70, size: 22),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),

              // User avatar + name + role
              const _TopbarUserInfo(),
              const SizedBox(width: 4),

              // Logout button
              _LogoutButton(),
              const SizedBox(width: 8),
            ],
          ),

          // ── MOBILE DRAWER ────────────────────────────────────────────────
          drawer: isDesktop
              ? null
              : Drawer(
                  child: _SidebarContent(currentRoute: currentRoute),
                ),

          // ── BODY: sidebar (desktop) + page content ───────────────────────
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fixed sidebar on desktop
              if (isDesktop)
                SizedBox(
                  width: 240,
                  child: _SidebarContent(currentRoute: currentRoute),
                ),
              // Main content area
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SidebarContent — the full sidebar content
//
// FIX for BOTTOM OVERFLOWED:
//   The sidebar is now a Column with:
//     1. Fixed header (company name + user info)
//     2. Expanded + SingleChildScrollView for nav items
//     3. Fixed footer (logout button)
//   This prevents overflow when there are many nav items
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarContent extends StatefulWidget {
  final String currentRoute;
  const _SidebarContent({required this.currentRoute});

  @override
  State<_SidebarContent> createState() => _SidebarContentState();
}

class _SidebarContentState extends State<_SidebarContent> {
  String _companyName = 'Mon Restaurant';
  String _userName    = 'Utilisateur';
  String _userRole    = 'Rôle';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // Read stored values
    String storedCompany = prefs.getString(kCompanyName) ?? '';
    String storedName    = prefs.getString(kUserName)    ?? '';
    String storedRole    = prefs.getString(kUserRole)    ?? '';

    // If company name is empty or still default, fetch from API
    if (storedCompany.isEmpty || storedCompany == 'Mon Restaurant') {
      try {
        // GET /api/v1/company/list returns the list of companies for this user
        final api = ApiService();
        final res = await api.get('/company/list');
        if (res.success && res.data is List && (res.data as List).isNotEmpty) {
          // Take the first company as the active one
          final company = (res.data as List).first;
          storedCompany = company['nameComp'] ?? 'Mon Restaurant';
          // Save it so next load is instant
          await prefs.setString(kCompanyName, storedCompany);
          await prefs.setString(
              kCompanyId, company['id']?.toString() ?? '');
        }
      } catch (_) {
        // If API fails, keep the stored value
        storedCompany = storedCompany.isEmpty ? 'Mon Restaurant' : storedCompany;
      }
    }

    // If username is email (from login), try to extract the name part
    if (storedName.contains('@')) {
      storedName = storedName.split('@').first;
      await prefs.setString(kUserName, storedName);
    }

    if (!mounted) return;
    setState(() {
      _companyName = storedCompany.isEmpty ? 'Mon Restaurant' : storedCompany;
      _userName    = storedName.isEmpty    ? 'Utilisateur'    : storedName;
      _userRole    = storedRole.isEmpty    ? 'Rôle'           : storedRole;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSidebarBg,
      // FIX: Column with fixed header + scrollable middle + fixed footer
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER: Restaurant name (NOT the app logo) ───────────────────
          // This shows the currently active restaurant
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              // Extra top padding on mobile to avoid the status bar
              top: MediaQuery.of(context).padding.top > 0
                  ? MediaQuery.of(context).padding.top + 8
                  : 20,
              bottom: 16,
            ),
            color: kSidebarHeader,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 1),
                  ),
                  child: const Center(
                    child: Icon(Icons.restaurant,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(height: 8),
                // Active restaurant name
                Text(
                  _companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const Text(
                  'Restaurant actif',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),

          // ── USER INFO CARD ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Avatar circle with first letter of name
                CircleAvatar(
                  radius: 17,
                  backgroundColor: kAccent,
                  child: Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User name
                      Text(
                        _userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Role badge — colored by role type
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _roleColor(_userRole).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _userRole,
                          style: TextStyle(
                              color: _roleColor(_userRole),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── SCROLLABLE NAV ITEMS ─────────────────────────────────────────
          // FIX: Expanded + SingleChildScrollView prevents overflow
          Expanded(
            child: SingleChildScrollView(
              // Allow the nav list to scroll if there are many items
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── NAVIGATION ───────────────────────────────────────
                  // Dashboard — ROLE_MANAGER + ROLE_ADMIN
                  RoleVisible(
                    allowedRoles: [AppRole.admin, AppRole.manager],
                    child: Column(children: [
                      _sectionLabel("NAVIGATION"),
                      _NavItem(
                        icon: Icons.dashboard_outlined,
                        label: "Dashboard",
                        route: '/dashboard',
                        currentRoute: widget.currentRoute,
                        onTap: () => _navigate(context, const DashboardPage()),
                      ),
                    ]),
                  ),

                  // Commandes — ALL roles (waiter, teller, manager, admin)
                  RoleVisible(
                    allowedRoles: [AppRole.admin, AppRole.manager,
                        AppRole.teller, AppRole.waiter],
                    child: _NavItem(
                      icon: Icons.receipt_long_outlined,
                      label: "Commandes",
                      route: '/order',
                      currentRoute: widget.currentRoute,
                      onTap: () => _navigate(context, const OrderPage()),
                    ),
                  ),

                  // Ventes — ROLE_TELLER + ROLE_MANAGER + ROLE_ADMIN
                  RoleVisible(
                    allowedRoles: [AppRole.admin, AppRole.manager, AppRole.teller],
                    child: _NavItem(
                      icon: Icons.point_of_sale_outlined,
                      label: "Ventes",
                      route: '/sale',
                      currentRoute: widget.currentRoute,
                      onTap: () => _navigate(context, const SalePage()),
                    ),
                  ),

                  // ── CATALOGUE ────────────────────────────────────────────
                  // All CATALOGUE items — ROLE_MANAGER + ROLE_ADMIN
                  // Waiter can only SEE products in the order page (not manage them)
                  RoleVisible(
                    allowedRoles: [AppRole.admin, AppRole.manager],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel("CATALOGUE"),
                        _NavItem(
                          icon: Icons.shopping_bag_outlined,
                          label: "Produits",
                          route: '/product',
                          currentRoute: widget.currentRoute,
                          onTap: () => _navigate(context, const ProductPage()),
                        ),
                        _NavItem(
                          icon: Icons.category_outlined,
                          label: "Catégories",
                          route: '/category',
                          currentRoute: widget.currentRoute,
                          onTap: () => _navigate(context, const CategoryPage()),
                        ),
                        _NavItem(
                          icon: Icons.local_shipping_outlined,
                          label: "Fournisseurs",
                          route: '/supplier',
                          currentRoute: widget.currentRoute,
                          onTap: () => _navigate(context, const SupplierPage()),
                        ),
                        _NavItem(
                          icon: Icons.swap_vert_outlined,
                          label: "Mvt. de Stock",
                          route: '/stock',
                          currentRoute: widget.currentRoute,
                          onTap: () => _navigate(context, const StockMovementPage()),
                        ),
                      ],
                    ),
                  ),

                  // ── GESTION ───────────────────────────────────────────────
                  // Mes Restaurants — ROLE_ADMIN only
                  RoleVisible(
                    allowedRoles: [AppRole.admin],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel("GESTION"),
                        _NavItem(
                          icon: Icons.store_outlined,
                          label: "Mes Restaurants",
                          route: '/company',
                          currentRoute: widget.currentRoute,
                          onTap: () => _navigate(context, const CompanyPage()),
                        ),
                      ],
                    ),
                  ),

                  // Utilisateurs — ROLE_MANAGER + ROLE_ADMIN
                  RoleVisible(
                    allowedRoles: [AppRole.admin, AppRole.manager],
                    child: _NavItem(
                      icon: Icons.people_outline,
                      label: "Utilisateurs",
                      route: '/users',
                      currentRoute: widget.currentRoute,
                      onTap: () => _navigate(context, const UsersPage()),
                    ),
                  ),

                  // Bottom spacing so last item isn't hidden by footer
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── FOOTER: Logout button — always visible ───────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
            ),
            child: _NavItem(
              icon: Icons.logout_outlined,
              label: "Déconnexion",
              route: '',
              currentRoute: '',
              iconColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              onTap: () => _logout(context),
            ),
          ),

          // Safe area bottom padding on mobile
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  // ── Section label helper ───────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  // ── Navigate with route replacement ───────────────────────────────────────
  void _navigate(BuildContext context, Widget page) {
    // Close drawer on mobile before navigating
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Logout: clear all saved data and go to login ──────────────────────────
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ── Role color helper ──────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'administrateur':
        return Colors.redAccent;
      case 'manager':
        return Colors.orangeAccent;
      case 'caissier':
        return Colors.lightBlueAccent;
      case 'serveur':
        return kAccent;
      default:
        return Colors.white54;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopbarUserInfo — user avatar + name + role in the top app bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopbarUserInfo extends StatefulWidget {
  const _TopbarUserInfo();

  @override
  State<_TopbarUserInfo> createState() => _TopbarUserInfoState();
}

class _TopbarUserInfoState extends State<_TopbarUserInfo> {
  String _userName = '';
  String _userRole = 'Rôle';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString(kUserName) ?? '';
      _userRole = prefs.getString(kUserRole) ?? 'Rôle';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: kPrimary,
          child: Text(
            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            // Role shown in topbar too
            Text(_userRole,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LogoutButton — logout icon button in topbar
// ─────────────────────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_outlined,
          color: Colors.white70, size: 20),
      tooltip: "Déconnexion",
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavItem — a single navigation item in the sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
    this.iconColor = Colors.white,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // Highlight this item if its route matches the current page
    final isActive = currentRoute == route && route.isNotEmpty;

    return InkWell(
      onTap: onTap,
      highlightColor: Colors.white10,
      splashColor: Colors.white10,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          // Highlighted background for active item
          color: isActive
              ? Colors.white.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: Colors.white.withOpacity(0.15))
              : null,
        ),
        child: Row(
          children: [
            // Icon with accent background when active
            Container(
              padding: const EdgeInsets.all(4),
              decoration: isActive
                  ? BoxDecoration(
                      color: kAccent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(5),
                    )
                  : null,
              child: Icon(icon,
                  color: isActive ? Colors.white : iconColor, size: 17),
            ),
            const SizedBox(width: 9),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : labelColor,
                  fontSize: 13,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Active dot indicator
            if (isActive)
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    color: kAccent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}