import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/role_service.dart';
import 'register_page.dart';
import '../company/create_company_page.dart';
import '../dashboard/dashboard_page.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE DE CONNEXION
// POST /api/v1/user/login
// → Décode le JWT pour extraire rôle + nom + email
// → Redirige selon le rôle
// ═══════════════════════════════════════════════════════════════
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Appel API Login ──────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final api = ApiService();
    final res = await api.post('/user/login', {
      'email': _emailCtrl.text.trim(),
      'password': _passCtrl.text,
    });

    setState(() => _loading = false);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final token = res.data['token'];
      if (token != null) {
        // ── Sauvegarder le token ─────────────────────────────
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kTokenKey, token);

        // ── Décoder le JWT et sauvegarder rôle + infos ───────
        await _saveUserFromJwt(token);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } else {
      showError(context, res.error ?? 'Identifiants invalides');
    }
  }

  // ── Décoder JWT Symfony et sauvegarder les infos ─────────────
  Future<void> _saveUserFromJwt(String token) async {
    final payload = RoleService.decodeJwt(token);
    final roleService = RoleService();

    // Récupérer le rôle le plus élevé
    // Symfony envoie: ["ROLE_MANAGER", "ROLE_USER"] ou ["ROLE_ADMIN"]
    final roles = (payload['roles'] as List<dynamic>?) ?? [];
    String mainRole = 'ROLE_WAITER';

    if (roles.contains('ROLE_ADMIN')) {
      mainRole = 'ROLE_ADMIN';
    } else if (roles.contains('ROLE_MANAGER')) {
      mainRole = 'ROLE_MANAGER';
    } else if (roles.contains('ROLE_TELLER')) {
      mainRole = 'ROLE_TELLER';
    } else if (roles.contains('ROLE_WAITER')) {
      mainRole = 'ROLE_WAITER';
    }

    // Sauvegarder dans SharedPreferences via RoleService
    await roleService.saveRole(mainRole);

    // Nom: essayer "name" d'abord, sinon "username", sinon email
    final name = payload['name'] ??
        payload['username'] ??
        _emailCtrl.text.split('@').first;
    await roleService.saveName(name.toString());

    // Email
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserEmail, _emailCtrl.text.trim());
    await prefs.setString(
        kUserRole, RoleService.roleLabel(mainRole));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Row(
            children: [
              // ── Panneau gauche décoratif ─────────────────────
              if (isWide)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kSidebarHeader, kPrimary, kPrimaryLight],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo fictif
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2),
                            ),
                            child:// ClipRRect — clips its child widget with rounded corners
// Without this, the image would have sharp square corners
ClipRRect(
  // borderRadius — how rounded the corners are
  // circular(8) = 8 pixels of rounding on all 4 corners
  borderRadius: BorderRadius.circular(8),

  // child — the widget to display inside the rounded clip
  child: Image.asset(
    // path to the image file inside the assets/ folder
    // declared in pubspec.yaml under flutter: assets:
    'assets/logo.png',

    // width — horizontal size of the image in pixels
    width: 36,

    // height — vertical size of the image in pixels
    height: 36,

    // fit: BoxFit.contain — scales the image to fit inside
    // the 36x36 box WITHOUT cropping or stretching it
    // Other options:
    //   BoxFit.cover  = fills the box, may crop edges
    //   BoxFit.fill   = stretches to fill, may distort
    //   BoxFit.contain = keeps aspect ratio, fits inside ✅
    fit: BoxFit.contain,
  ),
),
                          ),
                          const SizedBox(height: 32),
                          const Text("CaisseExpress",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 12),
                          const Text(
                              "Système de Gestion\nde Point de Vente",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  height: 1.5)),
                          const SizedBox(height: 48),
                          _featureItem(Icons.speed, "Commandes rapides"),
                          const SizedBox(height: 16),
                          _featureItem(Icons.analytics_outlined,
                              "Statistiques en temps réel"),
                          const SizedBox(height: 16),
                          _featureItem(Icons.shield_outlined,
                              "Accès par rôle (Admin / Manager / Caissier / Serveur)"),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Formulaire ───────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isWide) ...[
                            const Center(
                              child: Text('R',
                                  style: TextStyle(
                                      color: kPrimary,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Text("Connexion",
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary)),
                          const SizedBox(height: 6),
                          const Text(
                              "Entrez vos identifiants pour accéder",
                              style: TextStyle(
                                  color: kTextSecondary, fontSize: 14)),
                          const SizedBox(height: 36),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                AppTextField(
                                  label: "Email",
                                  hint: "votremail@exemple.com",
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Email requis';
                                    if (!v.contains('@'))
                                      return 'Email invalide';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  label: "Mot de passe",
                                  controller: _passCtrl,
                                  obscureText: !_showPassword,
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: kTextSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                        _showPassword = !_showPassword),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty)
                                          ? 'Mot de passe requis'
                                          : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: "Se connecter",
                            onPressed: _login,
                            isLoading: _loading,
                            icon: Icons.login,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Pas encore de compte ?",
                                  style: TextStyle(
                                      color: kTextSecondary, fontSize: 14)),
                              TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterPage())),
                                child: const Text("Créer un compte",
                                    style: TextStyle(
                                        color: kPrimary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}