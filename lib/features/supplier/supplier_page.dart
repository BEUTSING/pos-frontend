import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE FOURNISSEURS
// GET    /api/v1/supplier/list
// POST   /api/v1/supplier/create
// PUT    /api/v1/supplier/modify/{id}
// DELETE /api/v1/supplier/delete/{id}
// ═══════════════════════════════════════════════════════════════
class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _api = ApiService();
  List<dynamic> _suppliers = [];
  bool _loading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/supplier/list');
    setState(() {
      _loading = false;
      _suppliers = (res.success && res.data is List) ? res.data : [];
      _error = res.success ? '' : (res.error ?? 'Erreur');
    });
  }

  List<dynamic> get _filtered {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers
        .where((s) =>
            (s['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (s['email'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _openForm([dynamic supplier]) {
    showDialog(
      context: context,
      builder: (_) =>
          _SupplierDialog(supplier: supplier, onSaved: _load),
    );
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showConfirmDialog(context,
        title: 'Supprimer', message: 'Supprimer "$name" ?');
    if (ok != true) return;
    final res = await _api.delete('/supplier/delete/$id');
    if (!mounted) return;
    res.success
        ? showSuccess(context, 'Fournisseur supprimé')
        : showError(context, res.error ?? 'Erreur');
    if (res.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/supplier',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: Column(
              children: [
                PageHeader(
                  title: "Fournisseurs",
                  subtitle: "${_suppliers.length} fournisseur(s)",
                  action: ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Ajouter"),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: "Rechercher un fournisseur...",
                    prefixIcon: Icon(Icons.search,
                        color: kTextSecondary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _filtered.isEmpty
                    ? const Center(
                        child: Text("Aucun fournisseur",
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
                Expanded(flex: 1, child: _TH("Actions")),
              ],
            ),
          ),
          ..._filtered.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
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
                              kPrimary.withOpacity(0.12),
                          child: Text(
                            (s['name'] ?? 'F').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s['name'] ?? '',
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
                    child: Text(s['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: kTextSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(s['phone'] ?? '',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(s['city'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: kTextSecondary)),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: kInfoColor),
                          onPressed: () => _openForm(s),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outlined,
                              size: 16, color: kErrorColor),
                          onPressed: () => _delete(
                              (s['id'] is int ? s['id'] as int : int.tryParse(s['id'].toString()) ?? 0), s['name'] ?? ''),
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

class _SupplierDialog extends StatefulWidget {
  final dynamic supplier;
  final VoidCallback onSaved;
  const _SupplierDialog({this.supplier, required this.onSaved});

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.supplier['name'] ?? '';
      _emailCtrl.text = widget.supplier['email'] ?? '';
      _phoneCtrl.text = widget.supplier['phone'] ?? '';
      _cityCtrl.text = widget.supplier['city'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ApiService();
    final body = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
    };
    final res = _isEdit
        ? await api.put(
            '/supplier/modify/${widget.supplier['id']}', body)
        : await api.post('/supplier/create', body);

    setState(() => _saving = false);
    if (!mounted) return;
    if (res.success) {
      showSuccess(context,
          _isEdit ? 'Fournisseur modifié' : 'Fournisseur créé');
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
      title: Text(_isEdit ? 'Modifier' : 'Nouveau fournisseur',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: "Nom *",
                controller: _nameCtrl,
                prefixIcon: Icons.business_outlined,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: "Email *",
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) =>
                    (v == null || !v.contains('@'))
                        ? 'Email invalide'
                        : null,
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
            ],
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