// ─────────────────────────────────────────────────────────────────────────────
// FILE: register_page.dart
// PURPOSE: Registration page — lets a new user create an account
//
// FLOW (important to understand):
//   Step 1 → User fills the form and taps "Créer mon compte"
//   Step 2 → POST /api/v1/user/register   → creates the account in Symfony
//   Step 3 → POST /api/v1/user/login      → auto-login with same credentials
//   Step 4 → JWT token saved in SharedPreferences (local storage)
//   Step 5 → Redirect to CreateCompanyPage (token is now ready for API calls)
//
// WHY DO WE AUTO-LOGIN AFTER REGISTERING?
//   The endpoint POST /api/v1/company/create requires a valid JWT token
//   in the Authorization header. Right after registration, no token exists
//   yet (the register endpoint only creates the user, it does not return
//   a token). So we immediately call /user/login with the same email +
//   password to get the token before navigating to the next page.
//   The user sees nothing — it happens silently in the background.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // local key-value storage

// Core imports — shared across the whole app
import '../../core/constants.dart'; // colors, kBaseUrl, SharedPrefs keys
import '../../core/api_service.dart'; // HTTP helper (GET/POST/PUT/DELETE + JWT)
import '../../core/widgets.dart'; // AppTextField, PrimaryButton, showError…

// Pages we can navigate to from here
import 'login_page.dart'; // "Already have an account?" link + fallback
import '../company/create_company_page.dart'; // destination after success

// ─────────────────────────────────────────────────────────────────────────────
// RegisterPage — StatefulWidget because we have:
//   - form validation state (_formKey)
//   - loading spinner (_loading)
//   - password visibility toggle (_showPassword)
//   - selected color (_selectedColor)
// ─────────────────────────────────────────────────────────────────────────────
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  // ── Form key ──────────────────────────────────────────────────────────────
  // GlobalKey connects this widget to the Form below.
  // We call _formKey.currentState!.validate() to trigger all field validators
  // at once when the user taps the submit button.
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers — one per input field ────────────────────────────────
  // TextEditingController holds the current text value of a field.
  // We read .text to get the value, and .dispose() to free memory.
  final _nameCtrl  = TextEditingController(); // full name
  final _phoneCtrl = TextEditingController(); // phone number
  final _cityCtrl  = TextEditingController(); // city
  final _emailCtrl = TextEditingController(); // email address
  final _passCtrl  = TextEditingController(); // password

  // ── UI state variables ────────────────────────────────────────────────────
  bool _loading      = false; // true while API calls are running → shows spinner
  bool _showPassword = false; // true = show password characters, false = hide

  // ── Avatar color ──────────────────────────────────────────────────────────
  // The Symfony User entity has a "color" field (string).
  // We let the user pick a color that will be used for their avatar circle.
  String _selectedColor = 'green'; // default selection

  // List of color options shown as clickable circles
  final List<Map<String, dynamic>> _colors = [
    {'name': 'green',  'color': Colors.green},
    {'name': 'blue',   'color': Colors.blue},
    {'name': 'red',    'color': Colors.red},
    {'name': 'orange', 'color': Colors.orange},
    {'name': 'purple', 'color': Colors.purple},
    {'name': 'teal',   'color': Colors.teal},
  ];

  // ── dispose ───────────────────────────────────────────────────────────────
  // Always dispose controllers when the widget is removed from the tree.
  // This prevents memory leaks.
  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── _register ─────────────────────────────────────────────────────────────
  // Called when the user taps "Créer mon compte".
  // Makes 2 API calls in sequence: register then login.
  Future<void> _register() async {

    // Validate all fields — if any validator returns a non-null string,
    // the field shows an error and we stop here
    if (!_formKey.currentState!.validate()) return;

    // Show loading spinner and disable the button
    setState(() => _loading = true);

    final api = ApiService(); // our centralized HTTP service

    // ── CALL 1: Create the account ────────────────────────────────────────
    // POST /api/v1/user/register
    // No Authorization header needed — this endpoint is public
    // Symfony creates a new User with ROLE_ADMIN and returns the user data
    final res = await api.post('/user/register', {
      'name':     _nameCtrl.text.trim(),  // .trim() removes leading/trailing spaces
      'phone':    _phoneCtrl.text.trim(),
      'city':     _cityCtrl.text.trim(),
      'color':    _selectedColor,          // the color string chosen by the user
      'email':    _emailCtrl.text.trim(),
      'password': _passCtrl.text,          // raw password — Symfony will hash it
    });

    // If registration failed, show the error and stop
    if (!res.success) {
      setState(() => _loading = false);
      if (!mounted) return; // widget may have been disposed while waiting
      showError(context, res.error ?? 'Erreur lors de la création du compte');
      return;
    }

    // ── CALL 2: Auto-login ────────────────────────────────────────────────
    // POST /api/v1/user/login
    // We use the SAME email + password the user just typed.
    // Symfony validates them and returns a JWT token if correct.
    // This token is what every protected endpoint needs.
    final loginRes = await api.post('/user/login', {
      'email':    _emailCtrl.text.trim(),
      'password': _passCtrl.text,
    });

    // Hide loading spinner
    setState(() => _loading = false);

    // Guard: if the widget was removed from the tree while we were waiting,
    // do not try to navigate or show snackbars — it would crash
    if (!mounted) return;

    if (loginRes.success && loginRes.data != null) {

      // Extract the token from the response: {"token": "eyJhbG..."}
      final token = loginRes.data['token'];

      if (token != null) {
        // ── Save token + user info in SharedPreferences ───────────────────
        // SharedPreferences = local key-value storage on the device
        // This persists across app restarts until the user logs out
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(kTokenKey, token);               // JWT for API calls
        await prefs.setString(kUserName, _nameCtrl.text.trim()); // display name
        await prefs.setString(kUserEmail, _emailCtrl.text.trim()); // email
        await prefs.setString(kUserRole, 'Administrateur');    // new users = ROLE_ADMIN

        // Show success message (green snackbar at the bottom)
        showSuccess(context, 'Compte créé avec succès !');

        // ── Navigate to "Create your restaurant" page ─────────────────────
        // pushReplacement: replaces this page in the navigation stack.
        // The user cannot go "back" to the register page after this.
        // The token is now saved, so /company/create will work correctly.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CreateCompanyPage()),
        );
      }

    } else {
      // Rare case: account was created but auto-login failed
      // (e.g. server restarted between the two calls)
      // We redirect to login so the user can log in manually
      showSuccess(context,
          'Compte créé ! Connectez-vous pour continuer.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  // Describes the entire UI of this page.
  // LayoutBuilder gives us the available width so we can adapt the layout:
  //   > 700px → 2 columns (left decorative panel + right form)
  //   ≤ 700px → 1 column (form only, no decorative panel)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          return Row(
            children: [

              // ── LEFT DECORATIVE PANEL — desktop only ────────────────────
              // Hidden on narrow screens (mobile / small tablets)
              if (isWide)
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kPrimaryDark, kPrimary], // dark green → green
                      ),
                    ),
                    child:  Padding(
                      padding:const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          // Image.asset('assets/logo.png', width: 64)
                          // ClipRRect — clips its child widget with rounded corners
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
                          Text(
                            "Bienvenue sur\nCaisseExpress",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Créez votre compte pour commencer\nà gérer votre restaurant.",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── RIGHT SIDE — REGISTRATION FORM ──────────────────────────
              // Expanded takes all remaining horizontal space
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    // Allows scrolling when the keyboard is open
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      // Limit form width on very wide screens
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // ── Back button ───────────────────────────────
                          // Navigator.pop() goes back to the previous page
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios,
                                    size: 18, color: kTextSecondary),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Text("Retour",
                                  style: TextStyle(
                                      color: kTextSecondary, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Page title ────────────────────────────────
                          const Text(
                            "Créer un compte",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Remplissez les informations ci-dessous",
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 28),

                          // ── FORM ──────────────────────────────────────
                          // Form widget wraps all fields.
                          // autovalidateMode: disabled = validators only
                          // run when we call _formKey.currentState!.validate()
                          // NOT on every keystroke (avoids annoying red errors
                          // appearing before the user finishes typing)
                          Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.disabled,
                            child: Column(
                              children: [

                                // Full name
                                AppTextField(
                                  label: "Nom complet",
                                  controller: _nameCtrl,
                                  prefixIcon: Icons.person_outline,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Le nom est requis'
                                          : null,
                                  // validator returns null = valid
                                  // validator returns string = error message
                                ),
                                const SizedBox(height: 14),

                                // Phone + City — side by side using Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        label: "Téléphone",
                                        controller: _phoneCtrl,
                                        // TextInputType.phone shows numeric
                                        // keyboard on mobile
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
                                        label: "Ville",
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

                                // Email
                                // TextInputType.emailAddress shows @ on mobile
                                AppTextField(
                                  label: "Email",
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'L\'email est requis';
                                    // Basic format check
                                    if (!v.contains('@') || !v.contains('.'))
                                      return 'Entrez un email valide';
                                    return null; // null = valid
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password
                                // obscureText: true hides characters (shows ●●●)
                                // The eye icon button toggles _showPassword
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
                                    // Toggle password visibility
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.length < 3)
                                          ? 'Minimum 3 caractères'
                                          : null,
                                ),
                                const SizedBox(height: 16),

                                // ── Avatar color picker ───────────────────
                                // Shows colored circles the user can tap.
                                // The selected color gets a dark border + shadow.
                                // _selectedColor is sent to the API as a string.
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Couleur du profil",
                                      style: TextStyle(
                                          color: kTextSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      children: _colors.map((c) {
                                        final isSelected =
                                            _selectedColor == c['name'];
                                        return GestureDetector(
                                          onTap: () => setState(() =>
                                              _selectedColor = c['name']),
                                          child: AnimatedContainer(
                                            // AnimatedContainer smoothly
                                            // transitions between states
                                            duration: const Duration(
                                                milliseconds: 150),
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: c['color'] as Color,
                                              shape: BoxShape.circle,
                                              // Show border only when selected
                                              border: isSelected
                                                  ? Border.all(
                                                      color: kTextPrimary,
                                                      width: 2.5)
                                                  : null,
                                              // Show glow when selected
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                          color: (c['color']
                                                                  as Color)
                                                              .withOpacity(
                                                                  0.5),
                                                          blurRadius: 6)
                                                    ]
                                                  : null,
                                            ),
                                            // Show checkmark on selected circle
                                            child: isSelected
                                                ? const Icon(Icons.check,
                                                    color: Colors.white,
                                                    size: 16)
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Submit button ─────────────────────────────
                          // PrimaryButton shows a spinner when isLoading=true
                          // and disables taps to prevent double submissions
                          PrimaryButton(
                            label: "Créer mon compte",
                            onPressed: _register,
                            isLoading: _loading,
                            icon: Icons.person_add_outlined,
                          ),
                          const SizedBox(height: 16),

                          // ── Link to login page ────────────────────────
                          // pushReplacement: replaces this page with LoginPage
                          // so pressing back won't bring the user back here
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Vous avez déjà un compte ?",
                                  style: TextStyle(
                                      color: kTextSecondary, fontSize: 14)),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginPage())),
                                child: const Text("Se connecter",
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
}