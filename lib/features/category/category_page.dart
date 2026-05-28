import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE CATÉGORIES — Affichage en cartes
// GET    /api/v1/category/list
// POST   /api/v1/category/create
// PUT    /api/v1/category/modify/{id}
// DELETE /api/v1/category/delete/{id}
// ═══════════════════════════════════════════════════════════════
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _api = ApiService();
  List<dynamic> _categories = [];
  bool _loading = true;
  String _error = '';

  // Couleurs pour les cartes catégories
  final List<Color> _cardColors = [
    const Color(0xFF2E7D32),
    const Color(0xFF1565C0),
    const Color(0xFFE65100),
    const Color(0xFF4A148C),
    const Color(0xFF00695C),
    const Color(0xFF37474F),
    const Color(0xFFC62828),
    const Color(0xFF00838F),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.get('/category/list');
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _categories = res.data;
        _error = '';
      } else {
        _error = res.error ?? 'Aucune catégorie';
        _categories = [];
      }
    });
  }

  void _openForm([dynamic cat]) {
    showDialog(
      context: context,
      builder: (_) => _CategoryDialog(
        category: cat,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer la catégorie',
      message: 'Supprimer "$name" ? Les produits liés pourraient être affectés.',
      confirmText: 'Supprimer',
    );
    if (ok != true) return;

    final res = await _api.delete('/category/delete/$id');
    if (!mounted) return;
    if (res.success) {
      showSuccess(context, 'Catégorie supprimée');
      _load();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/category',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: PageHeader(
              title: "Catégories",
              subtitle: "${_categories.length} catégorie(s)",
              action: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Ajouter"),
              ),
            ),
          ),

          // Grille de cartes
          Expanded(
            child: _loading
                ? const AppLoader()
                : _categories.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined,
                                color: kTextSecondary, size: 56),
                            SizedBox(height: 12),
                            Text("Aucune catégorie créée",
                                style: TextStyle(
                                    color: kTextSecondary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) {
                          final cat = _categories[i];
                          final color = _cardColors[i % _cardColors.length];
                          return _CategoryCard(
                            category: cat,
                            color: color,
                            onEdit: () => _openForm(cat),
                            onDelete: () => _delete(
                                cat['id'] is int ? cat['id'] as int : int.tryParse(cat['id'].toString()) ?? 0,
                                cat['categoryname'] ?? ''),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Carte catégorie ──────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final dynamic category;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = category['categoryname'] ?? '';
    final desc = category['description'] ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Cercle décoratif
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -10,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 10),

                // Nom
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Description
                Expanded(
                  child: Text(
                    desc,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _CardButton(
                      icon: Icons.edit_outlined,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 6),
                    _CardButton(
                      icon: Icons.delete_outlined,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CardButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOG FORMULAIRE CATÉGORIE
// ═══════════════════════════════════════════════════════════════
class _CategoryDialog extends StatefulWidget {
  final dynamic category;
  final VoidCallback onSaved;

  const _CategoryDialog({this.category, required this.onSaved});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.category['categoryname'] ?? '';
      _descCtrl.text = widget.category['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ApiService();
    final body = {
      'categoryname': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };
    final res = _isEdit
        ? await api.put(
            '/category/modify/${widget.category['id']}', body)
        : await api.post('/category/create', body);

    setState(() => _saving = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(
          context, _isEdit ? 'Catégorie modifiée' : 'Catégorie créée');
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
        _isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: "Nom de la catégorie *",
                controller: _nameCtrl,
                prefixIcon: Icons.category_outlined,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: "Description *",
                controller: _descCtrl,
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
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