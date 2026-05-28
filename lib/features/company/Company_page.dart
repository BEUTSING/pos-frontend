// ─────────────────────────────────────────────────────────────────────────────
// FILE: company_page.dart
// PURPOSE: Manage restaurants/companies — list, create, edit, delete
//
// ONLY accessible to ROLE_ADMIN users (company owners)
//
// API CALLS:
//   GET    /api/v1/company/list         → list all companies of the current user
//   POST   /api/v1/company/create       → create a new company
//   PUT    /api/v1/company/modify/{id}  → update a company
//   DELETE /api/v1/company/delete/{id}  → delete a company
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  final _api = ApiService();
  List<dynamic> _companies = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load all companies of the logged-in user ──────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/company/list');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _companies = (res.success && res.data is List) ? res.data : [];
      _error = res.success ? '' : (res.error ?? 'Erreur');
    });
  }

  // ── Open create or edit dialog ────────────────────────────────────────────
  void _openForm([dynamic company]) {
    showDialog(
      context: context,
      builder: (_) => _CompanyDialog(company: company, onSaved: _load),
    );
  }

  // ── Delete a company ──────────────────────────────────────────────────────
  Future<void> _delete(int id, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer le restaurant',
      message:
          'Supprimer "$name" ? Toutes les données associées seront perdues.',
      confirmText: 'Supprimer',
    );
    if (ok != true) return;

    final res = await _api.delete('/company/delete/$id');
    if (!mounted) return;
    if (res.success) {
      showSuccess(context, 'Restaurant supprimé');
      _load();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  // ── Set active company (saved in SharedPreferences) ───────────────────────
  Future<void> _setActive(dynamic company) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kCompanyName, company['nameComp'] ?? '');
    await prefs.setString(kCompanyId, company['id']?.toString() ?? '');
    if (!mounted) return;
    showSuccess(context,
        '"${company['nameComp']}" est maintenant le restaurant actif');
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/company',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: PageHeader(
              title: "Mes Restaurants",
              subtitle: "${_companies.length} restaurant(s)",
              action: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Nouveau restaurant"),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoader()
                : _error.isNotEmpty
                    ? ErrorMessage(message: _error, onRetry: _load)
                    : _companies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant,
                                    color: kTextSecondary, size: 56),
                                const SizedBox(height: 12),
                                const Text("Aucun restaurant enregistré",
                                    style:
                                        TextStyle(color: kTextSecondary)),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _openForm(),
                                  icon: const Icon(Icons.add),
                                  label:
                                      const Text("Créer un restaurant"),
                                ),
                              ],
                            ),
                          )
                        : _buildGrid(),
          ),
        ],
      ),
    );
  }

  // ── Grid of company cards ─────────────────────────────────────────────────
  Widget _buildGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: 1 column mobile, 2 tablet, 3 desktop
          final crossCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          final itemW =
              (constraints.maxWidth - (crossCount - 1) * 16) / crossCount;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _companies.map((company) {
              return SizedBox(
                width: itemW,
                child: _CompanyCard(
                  company: company,
                  onEdit: () => _openForm(company),
                  onDelete: () =>
                      _delete(company['id'] as int, company['nameComp'] ?? ''),
                  onSetActive: () => _setActive(company),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CompanyCard — card showing one restaurant
// ═══════════════════════════════════════════════════════════════════════════
class _CompanyCard extends StatelessWidget {
  final dynamic company;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;

  const _CompanyCard({
    required this.company,
    required this.onEdit,
    required this.onDelete,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant,
                    color: kPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  company['nameComp'] ?? '',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: kBorderColor),
          const SizedBox(height: 12),

          // Info lines
          _infoRow(Icons.email_outlined, company['emailComp'] ?? '-'),
          const SizedBox(height: 6),
          _infoRow(Icons.phone_outlined, company['phone'] ?? '-'),
          const SizedBox(height: 6),
          _infoRow(
              Icons.location_city_outlined, company['city'] ?? '-'),
          const SizedBox(height: 6),
          _infoRow(Icons.people_outline,
              '${company['numEmpl'] ?? 0} employé(s)'),
          if ((company['siteWeb'] ?? '').isNotEmpty &&
              company['siteWeb'] != '#') ...[
            const SizedBox(height: 6),
            _infoRow(Icons.language_outlined, company['siteWeb']),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Set as active
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSetActive,
                  icon: const Icon(Icons.check_circle_outline,
                      size: 16, color: kPrimary),
                  label: const Text("Activer",
                      style: TextStyle(color: kPrimary, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: kInfoColor, size: 18),
                onPressed: onEdit,
                tooltip: "Modifier",
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outlined,
                    color: kErrorColor, size: 18),
                onPressed: onDelete,
                tooltip: "Supprimer",
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 12, color: kTextSecondary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CompanyDialog — create or edit a company
// ═══════════════════════════════════════════════════════════════════════════
class _CompanyDialog extends StatefulWidget {
  final dynamic company;
  final VoidCallback onSaved;
  const _CompanyDialog({this.company, required this.onSaved});

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _numEmplCtrl = TextEditingController(text: '1');
  final _siteWebCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.company != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text    = widget.company['nameComp'] ?? '';
      _emailCtrl.text   = widget.company['emailComp'] ?? '';
      _phoneCtrl.text   = widget.company['phone'] ?? '';
      _cityCtrl.text    = widget.company['city'] ?? '';
      _numEmplCtrl.text = widget.company['numEmpl']?.toString() ?? '1';
      _siteWebCtrl.text = widget.company['siteWeb'] ?? '';
    }
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = ApiService();
    final body = {
      'nameComp':  _nameCtrl.text.trim(),
      'emailComp': _emailCtrl.text.trim(),
      'phone':     _phoneCtrl.text.trim(),
      'city':      _cityCtrl.text.trim(),
      'numEmpl':   int.tryParse(_numEmplCtrl.text) ?? 1,
      'siteWeb': _siteWebCtrl.text.trim().isEmpty
          ? '#'
          : _siteWebCtrl.text.trim(),
    };

    final res = _isEdit
        ? await api.put('/company/modify/${widget.company['id']}', body)
        : await api.post('/company/create', body);

    setState(() => _saving = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(context,
          _isEdit ? 'Restaurant modifié !' : 'Restaurant créé !');
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
        _isEdit ? 'Modifier le restaurant' : 'Nouveau restaurant',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: "Nom du restaurant *",
                  controller: _nameCtrl,
                  prefixIcon: Icons.restaurant,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: "Email *",
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Email invalide' : null,
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
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requis'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Ville *",
                        controller: _cityCtrl,
                        prefixIcon: Icons.location_city_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requis'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Nb. employés",
                        controller: _numEmplCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Site web (optionnel)",
                        hint: "https://...",
                        controller: _siteWebCtrl,
                        prefixIcon: Icons.language_outlined,
                      ),
                    ),
                  ],
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