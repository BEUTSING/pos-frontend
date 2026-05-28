import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE PRODUITS
// GET    /api/v1/product/list
// POST   /api/v1/product/create
// PUT    /api/v1/product/modify/{id}
// DELETE /api/v1/product/delete/{id}
// ═══════════════════════════════════════════════════════════════
class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _api = ApiService();
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _suppliers = [];
  bool _loading = true;
  String _error = '';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results3 = await Future.wait([
      _api.get('/product/list'),
      _api.get('/category/list'),
      _api.get('/supplier/list'),
    ]);
    setState(() {
      _loading = false;
      _products = (results3[0].success && results3[0].data is List) ? results3[0].data : [];
      _categories = (results3[1].success && results3[1].data is List) ? results3[1].data : [];
      _suppliers = (results3[2].success && results3[2].data is List) ? results3[2].data : [];
      _error = (!results3[0].success) ? (results3[0].error ?? 'Erreur') : '';
    });
  }

  List<dynamic> get _filtered {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((p) => (p['productname'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ── Ouvrir dialog créer/modifier produit ─────────────────────
  void _openForm([dynamic product]) {
    showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(
        product: product,
        categories: _categories,
        suppliers: _suppliers,
        onSaved: _loadData,
      ),
    );
  }

  // ── Supprimer produit ────────────────────────────────────────
  Future<void> _delete(int id, String name) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Supprimer le produit',
      message: 'Supprimer "$name" ? Cette action est irréversible.',
      confirmText: 'Supprimer',
    );
    if (confirm != true) return;

    final res = await _api.delete('/product/delete/$id');
    if (!mounted) return;
    if (res.success) {
      showSuccess(context, 'Produit supprimé');
      _loadData();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/product',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: Column(
              children: [
                PageHeader(
                  title: "Produits",
                  subtitle: "${_products.length} produit(s)",
                  action: ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Ajouter"),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher un produit...",
                    prefixIcon: const Icon(Icons.search,
                        color: kTextSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: kTextSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // ── Tableau ───────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoader()
                : _error.isNotEmpty
                    ? ErrorMessage(
                        message: _error, onRetry: _loadData)
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text("Aucun produit trouvé",
                                style: TextStyle(
                                    color: kTextSecondary)))
                        : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: _TH("Nom")),
                  Expanded(flex: 2, child: _TH("Catégorie")),
                  Expanded(flex: 1, child: _TH("Prix vente")),
                  Expanded(flex: 1, child: _TH("Stock")),
                  Expanded(flex: 1, child: _TH("Stock min.")),
                  Expanded(flex: 1, child: _TH("Actions")),
                ],
              ),
            ),
            ..._filtered.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final stock = p['quantity'] ?? 0;
              final minStock = p['minimumstock'] ?? 0;
              final isLowStock = stock <= minStock;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i % 2 == 0 ? kCardBg : kBackground.withOpacity(0.5),
                  border: Border(
                      top: BorderSide(
                          color: kBorderColor.withOpacity(0.4))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        p['productname'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getCategoryName(p['category']),
                          style: const TextStyle(
                              fontSize: 11, color: kPrimary),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "${_safeNum(p['saleprice']).toStringAsFixed(0)} F",
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? kErrorColor
                                  : kSuccessColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$stock",
                            style: TextStyle(
                                fontSize: 13,
                                color: isLowStock
                                    ? kErrorColor
                                    : kTextPrimary,
                                fontWeight: isLowStock
                                    ? FontWeight.w600
                                    : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        "$minStock",
                        style: const TextStyle(
                            fontSize: 13,
                            color: kTextSecondary),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: kInfoColor),
                            tooltip: "Modifier",
                            onPressed: () => _openForm(p),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outlined,
                                size: 16, color: kErrorColor),
                            tooltip: "Supprimer",
                            onPressed: () => _delete(
                                p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0,
                                p['productname'] ?? ''),
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
      ),
    );
  }

  String _getCategoryName(dynamic category) {
    if (category is String) return category;
    if (category is Map) return category['name'] ?? '';
    return '';
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOG FORMULAIRE PRODUIT (Créer / Modifier)
// ═══════════════════════════════════════════════════════════════
// Safe number converter used across product page
double _safeNum(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

class _ProductFormDialog extends StatefulWidget {
  final dynamic product;
  final List<dynamic> categories;
  final List<dynamic> suppliers;
  final VoidCallback onSaved;

  const _ProductFormDialog({
    this.product,
    required this.categories,
    required this.suppliers,
    required this.onSaved,
  });

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product;
      _nameCtrl.text = p['productname'] ?? '';
      _salePriceCtrl.text =
          (p['saleprice'] ?? '').toString();
      _purchasePriceCtrl.text =
          (p['purchaseprice'] ?? '').toString();
      _qtyCtrl.text = (p['quantity'] ?? '').toString();
      _minStockCtrl.text =
          (p['minimumstock'] ?? '').toString();
      final cat = p['category'];
      if (cat is Map) _selectedCategoryId = cat['id'];
      final sup = p['supplier'];
      if (sup is Map) _selectedSupplierId = sup['id'];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _qtyCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      showError(context, 'Sélectionnez une catégorie');
      return;
    }
    setState(() => _saving = true);
    final api = ApiService();
    final body = {
      'productname': _nameCtrl.text.trim(),
      'category': _selectedCategoryId,
      'supplier': _selectedSupplierId,
      'saleprice': double.tryParse(_salePriceCtrl.text) ?? 0,
      'purchaseprice':
          double.tryParse(_purchasePriceCtrl.text) ?? 0,
      'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
      // minimumstock: use typed value OR 0 if left empty
      'minimumstock': _minStockCtrl.text.trim().isEmpty
          ? 0
          : int.tryParse(_minStockCtrl.text) ?? 0,
    };

    final res = _isEdit
        ? await api.put(
            '/product/modify/${widget.product['id']}', body)
        : await api.post('/product/create', body);

    setState(() => _saving = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(
          context, _isEdit ? 'Produit modifié' : 'Produit créé');
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
        _isEdit ? 'Modifier le produit' : 'Nouveau produit',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: "Nom du produit *",
                  controller: _nameCtrl,
                  prefixIcon: Icons.fastfood_outlined,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                // Catégorie
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: "Catégorie *",
                    prefixIcon: const Icon(Icons.category_outlined,
                        color: kTextSecondary, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: widget.categories
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString()) ?? 0,
                            child: Text(c['categoryname'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategoryId = v),
                  validator: (v) =>
                      v == null ? 'Sélectionnez une catégorie' : null,
                ),
                const SizedBox(height: 12),
                // Fournisseur
                DropdownButtonFormField<int?>(
                  value: _selectedSupplierId,
                  decoration: InputDecoration(
                    labelText: "Fournisseur (optionnel)",
                    prefixIcon: const Icon(
                        Icons.local_shipping_outlined,
                        color: kTextSecondary,
                        size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text("Aucun")),
                    ...widget.suppliers.map((s) =>
                        DropdownMenuItem<int?>(
                          value: s['id'] is int ? s['id'] as int : int.tryParse(s['id'].toString()) ?? 0,
                          child: Text(s['name'] ?? ''),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedSupplierId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Prix vente *",
                        controller: _salePriceCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.sell_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        label: "Prix achat *",
                        controller: _purchasePriceCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.shopping_cart_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: "Quantité *",
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.inventory_2_outlined,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        // Optional — no validator, defaults to 0
                        label: "Stock min. (optionnel)",
                        controller: _minStockCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.warning_amber_outlined,
                        // No validator — not required
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

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: kTextSecondary));
  }
}