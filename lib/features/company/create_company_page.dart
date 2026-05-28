// ─────────────────────────────────────────────────────────────────────────────
// FILE: create_company_page.dart
// PURPOSE: "Create your restaurant" page — shown right after registration
//
// FLOW:
//   Register → auto-login → THIS PAGE → Dashboard
//
// API CALL:
//   POST /api/v1/company/create
//   Requires JWT token (ROLE_ADMIN) — already saved by register_page.dart
//
// REQUIRED FIELDS (Symfony validation):
//   nameComp, emailComp, phone, city, numEmpl, siteWeb
//
// NOTE about siteWeb:
//   Even though siteWeb is required by Symfony, we send a default value
//   if the user leaves it empty, so the user does not need to fill it.
//   We send '#' as a placeholder if empty.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../dashboard/dashboard_page.dart';

class CreateCompanyPage extends StatefulWidget {
  const CreateCompanyPage({super.key});

  @override
  State<CreateCompanyPage> createState() => _CreateCompanyPageState();
}

class _CreateCompanyPageState extends State<CreateCompanyPage> {

  // ── Form key ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers — one per input field ────────────────────────────────
  final _nameCtrl    = TextEditingController(); // restaurant name (required)
  final _emailCtrl   = TextEditingController(); // restaurant email (required)
  final _phoneCtrl   = TextEditingController(); // phone number (required)
  final _cityCtrl    = TextEditingController(); // city (required)
  final _numEmplCtrl = TextEditingController(text: '1'); // nb employees (default: 1)
  final _siteWebCtrl = TextEditingController(); // website — OPTIONAL for the user
  //                                              ↑ if empty, we send '#' to Symfony
  //                                              because Symfony requires the field
  //                                              but we don't want to bother the user

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _loading = false; // true while API call is running → shows spinner

  // ── dispose — free memory when widget is removed ──────────────────────────
  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _numEmplCtrl.dispose();
    _siteWebCtrl.dispose();
    super.dispose();
  }

  // ── _createCompany — called when user taps "Créer mon restaurant" ─────────
  Future<void> _createCompany() async {

    // Step 1: validate required fields only — siteWeb is optional
    if (!_formKey.currentState!.validate()) return;

    // Step 2: show loading spinner
    setState(() => _loading = true);

    final api = ApiService();

    // Step 3: call the API
    // POST /api/v1/company/create
    // Symfony requires: nameComp, emailComp, phone, city, numEmpl, siteWeb
    // For siteWeb: we send the user's input OR '#' if they left it empty
    // This way the field is never blank (Symfony won't reject it)
    final res = await api.post('/company/create', {
      'nameComp':  _nameCtrl.text.trim(),
      'emailComp': _emailCtrl.text.trim(),
      'phone':     _phoneCtrl.text.trim(),
      'city':      _cityCtrl.text.trim(),
      'numEmpl':   int.tryParse(_numEmplCtrl.text) ?? 1,
      // siteWeb: use what the user typed, or '#' as a safe placeholder
      'siteWeb': _siteWebCtrl.text.trim().isEmpty
          ? '#'
          : _siteWebCtrl.text.trim(),
    });

    // Step 4: hide spinner
    setState(() => _loading = false);

    // Guard: widget may have been disposed while waiting
    if (!mounted) return;

    if (res.success) {

      // Step 5: save company info in SharedPreferences for later use
      // (displayed in the sidebar, dashboard header, etc.)
      if (res.data is List && res.data.isNotEmpty) {
        final company = res.data[0]; // Symfony returns a list with 1 item
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kCompanyName, company['nameComp'] ?? '');
        await prefs.setString(kCompanyId, company['id']?.toString() ?? '');
      }

      // Show success snackbar
      showSuccess(context, 'Restaurant créé avec succès !');

      // Step 6: navigate to Dashboard
      // pushAndRemoveUntil: clears the entire navigation stack
      // The user cannot go "back" to register or create-company pages
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false, // remove ALL previous routes
      );

    } else {
      // Show the API error message
      showError(context, res.error ?? 'Erreur lors de la création');
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // isWide: true on desktop/tablet, false on mobile
          final isWide = constraints.maxWidth > 700;

          return Row(
            children: [

              // ── LEFT DECORATIVE PANEL — desktop only ─────────────────────
              if (isWide)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kPrimaryDark, kPrimary, kAccent],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Restaurant icon in a frosted circle
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "Créez votre\nrestaurant",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Configurez votre établissement\npour commencer à gérer vos ventes.",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.6),
                          ),
                          const SizedBox(height: 40),

                          // Step indicators — shows where the user is in the flow
                          _step("1", "Créez votre compte"),
                          const SizedBox(height: 12),
                          // Step 2 is active (current step)
                          _step("2", "Configurez votre restaurant",
                              active: true),
                          const SizedBox(height: 12),
                          _step("3", "Accédez au tableau de bord"),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── RIGHT SIDE — RESTAURANT FORM ─────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // ── Page title ───────────────────────────────────
                          const Text(
                            "Informations du restaurant",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Les champs marqués * sont obligatoires",
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 28),

                          // ── FORM ─────────────────────────────────────────
                          Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.disabled,
                            child: Column(
                              children: [

                                // Restaurant name — required
                                AppTextField(
                                  label: "Nom du restaurant *",
                                  hint: "Ex: Le Gourmet Camerounais",
                                  controller: _nameCtrl,
                                  prefixIcon: Icons.restaurant,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Le nom est requis'
                                          : null,
                                ),
                                const SizedBox(height: 14),

                                // Email — required
                                AppTextField(
                                  label: "Email du restaurant *",
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Email invalide'
                                          : null,
                                ),
                                const SizedBox(height: 14),

                                // Phone + City on same row
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        label: "Téléphone *",
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        prefixIcon: Icons.phone_outlined,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Requis'
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: AppTextField(
                                        label: "Ville *",
                                        controller: _cityCtrl,
                                        prefixIcon:
                                            Icons.location_city_outlined,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Requis'
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Nb employees + Website on same row
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        // No validator = not required
                                        label: "Nb. employés",
                                        controller: _numEmplCtrl,
                                        keyboardType: TextInputType.number,
                                        prefixIcon: Icons.people_outline,
                                        // No validator — defaults to 1
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: AppTextField(
                                        // OPTIONAL — no * and no validator
                                        // If empty, we send '#' to the API
                                        label: "Site web (optionnel)",
                                        hint: "https://...",
                                        controller: _siteWebCtrl,
                                        prefixIcon: Icons.language_outlined,
                                        // No validator — field is optional
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Submit button ─────────────────────────────────
                          PrimaryButton(
                            label: "Créer mon restaurant",
                            onPressed: _createCompany,
                            isLoading: _loading,
                            icon: Icons.restaurant,
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

  // ── _step — helper widget for the step indicator on the left panel ─────────
  // Draws a numbered circle + label.
  // active: true = white circle with green text (current step)
  // active: false = transparent circle with white text (other steps)
  Widget _step(String num, String label, {bool active = false}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active
                ? Colors.white                     // highlighted: solid white
                : Colors.white.withOpacity(0.3),   // other: semi-transparent
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: TextStyle(
                color: active ? kPrimary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}