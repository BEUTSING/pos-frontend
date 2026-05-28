import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE UTILISATEURS
// GET    /api/v1/user/list
// POST   /api/v1/user/create
// PUT    /api/v1/user/modify/{id}
// DELETE /api/v1/user/delete/{id}
// ═══════════════════════════════════════════════════════════════
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/user/list');
    setState(() {
      _loading = false;
      _users = (res.success && res.data is List) ? res.data : [];
    });
  }

  void _openForm([dynamic user]) {
    showDialog(
      context: context,
      builder: (_) => _UserDialog(user: user, onSaved: _load),
    );
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer', message: 'Supprimer "$name" ?');
    if (ok != true) return;
    final res = await _api.delete('/user/delete/$id');
    if (!mounted) return;
    res.success
        ? showSuccess(context, 'Utilisateur supprimé')
        : showError(context, res.error ?? 'Erreur');
    if (res.success) _load();
  }

  Color _roleColor(List<dynamic> roles) {
    if (roles.contains('ROLE_ADMIN')) return kErrorColor;
    if (roles.contains('ROLE_MANAGER')) return kWarningColor;
    if (roles.contains('ROLE_TELLER')) return kInfoColor;
    return kSuccessColor;
  }

  String _roleName(List<dynamic> roles) {
    if (roles.contains('ROLE_ADMIN')) return 'Admin';
    if (roles.contains('ROLE_MANAGER')) return 'Manager';
    if (roles.contains('ROLE_TELLER')) return 'Caissier';
    if (roles.contains('ROLE_WAITER')) return 'Serveur';
    return 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/users',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: PageHeader(
              title: "Utilisateurs",
              subtitle: "${_users.length} utilisateur(s)",
              action: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text("Ajouter"),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _users.isEmpty
                    ? const Center(
                        child: Text("Aucun utilisateur",
                            style:
                                TextStyle(color: kTextSecondary)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildTable(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _TH("Nom")),
                Expanded(flex: 2, child: _TH("Email")),
                Expanded(flex: 1, child: _TH("Téléphone")),
                Expanded(flex: 1, child: _TH("Ville")),
                Expanded(flex: 1, child: _TH("Rôle")),
                Expanded(flex: 1, child: _TH("Actions")),
              ],
            ),
          ),
          ..._users.asMap().entries.map((entry) {
            final i = entry.key;
            final u = entry.value;
            final roles = (u['roles'] as List?) ?? [];
            final roleColor = _roleColor(roles);
            final roleName = _roleName(roles);

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i % 2 == 0
                    ? kCardBg
                    : kBackground.withOpacity(0.5),
                border: Border(
                    top: BorderSide(
                        color: kBorderColor.withOpacity(0.4))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              roleColor.withOpacity(0.15),
                          child: Text(
                            (u['name'] ?? 'U').substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(u['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(u['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: kTextSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(u['phone'] ?? '',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(u['city'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: kTextSecondary)),
                  ),
                  Expanded(
                    flex: 1,
                    child: StatusBadge(
                        label: roleName, color: roleColor),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: kInfoColor),
                          onPressed: () => _openForm(u),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outlined,
                              size: 16, color: kErrorColor),
                          onPressed: () => _delete(
                              (u['id'] is int ? u['id'] as int : int.tryParse(u['id'].toString()) ?? 0), u['name'] ?? ''),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Dialog Utilisateur ────────────────────────────────────────
class _UserDialog extends StatefulWidget {
  final dynamic user;
  final VoidCallback onSaved;
  const _UserDialog({this.user, required this.onSaved});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'ROLE_WAITER';
  bool _saving = false;

  bool get _isEdit => widget.user != null;

  final List<Map<String, String>> _roles = [
    {'value': 'ROLE_WAITER', 'label': 'Serveur'},
    {'value': 'ROLE_TELLER', 'label': 'Caissier'},
    {'value': 'ROLE_MANAGER', 'label': 'Manager'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.user;
      _nameCtrl.text = u['name'] ?? '';
      _phoneCtrl.text = u['phone'] ?? '';
      _cityCtrl.text = u['city'] ?? '';
      _emailCtrl.text = u['email'] ?? '';
      final roles = (u['roles'] as List?) ?? [];
      if (roles.isNotEmpty) {
        _selectedRole = roles.first.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ApiService();
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'color': 'green',
      'role': [_selectedRole],
    };
    if (_passCtrl.text.isNotEmpty) {
      body['password'] = _passCtrl.text;
    }

    final res = _isEdit
        ? await api.put('/user/modify/${widget.user['id']}', body)
        : await api.post('/user/create', body);

    setState(() => _saving = false);
    if (!mounted) return;
    if (res.success) {
      showSuccess(context,
          _isEdit ? 'Utilisateur modifié' : 'Utilisateur créé');
      widget.onSaved();
      Navigator.pop(context);
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
          _isEdit ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: "Nom complet *",
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Téléphone *",
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Ville *",
                        controller: _cityCtrl,
                        prefixIcon: Icons.location_city_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: "Email *",
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email invalide'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: _isEdit
                      ? "Nouveau mot de passe (optionnel)"
                      : "Mot de passe *",
                  controller: _passCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  validator: _isEdit
                      ? null
                      : (v) => (v == null || v.length < 3)
                          ? 'Min. 3 caractères'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Rôle *",
                    prefixIcon: const Icon(Icons.badge_outlined,
                        color: kTextSecondary, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                            value: r['value'],
                            child: Text(r['label']!),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedRole = v!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: kTextSecondary))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(_isEdit ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: kTextSecondary));
}