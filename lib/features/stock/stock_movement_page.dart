import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE MOUVEMENTS DE STOCK
//
// Endpoints utilisés :
//   GET  /api/v1/stock-movement/list               → tous les mouvements
//   GET  /api/v1/stock-movement/search/product/{pname} → recherche par produit
//   GET  /api/v1/stock-movement/search/type/{type} → filtre in/out
//   POST /api/v1/stock-movement/create             → créer un mouvement
//   PUT  /api/v1/stock-movement/modify/{id}        → modifier
//   DELETE /api/v1/stock-movement/delete/{id}      → supprimer
//
// Raisons possibles (enum ReasonMovement côté Symfony) :
//   purchase, sale, transfer_in, transfer_out,
//   loss, adjustment, return, other
// ═══════════════════════════════════════════════════════════════
class StockMovementPage extends StatefulWidget {
  const StockMovementPage({super.key});

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  late TabController _tabController;

  // ── Données ──────────────────────────────────────────────────
  List<dynamic> _movements = [];
  List<dynamic> _products = [];
  bool _loading = true;
  String _error = '';

  // ── Recherche + filtre ────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _typeFilter; // null = tous, 'in', 'out'

  // Raisons de mouvement (enum ReasonMovement)
  static const List<Map<String, String>> kReasons = [
    {'value': 'purchase', 'label': 'Achat'},
    {'value': 'sale', 'label': 'Vente'},
    {'value': 'transfer_in', 'label': 'Transfert entrant'},
    {'value': 'transfer_out', 'label': 'Transfert sortant'},
    {'value': 'loss', 'label': 'Perte'},
    {'value': 'adjustment', 'label': 'Ajustement'},
    {'value': 'return', 'label': 'Retour'},
    {'value': 'other', 'label': 'Autre'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Charger mouvements + produits ────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results4 = await Future.wait([
      _api.get('/stock-movement/list'),
      _api.get('/product/list'),
    ]);
    setState(() {
      _loading = false;
      _movements =
          (results4[0].success && results4[0].data is List) ? results4[0].data : [];
      _products =
          (results4[1].success && results4[1].data is List) ? results4[1].data : [];
      _error = (!results4[0].success) ? (results4[0].error ?? 'Erreur') : '';
    });
  }

  // ── Charger par type (in / out) ──────────────────────────────
  Future<void> _loadByType(String type) async {
    setState(() => _loading = true);
    final res = await _api.get('/stock-movement/search/type/$type');
    // Guard: widget may have been disposed while waiting
    if (!mounted) return;
    setState(() {
      _loading = false;
      _movements =
          (res.success && res.data is List) ? res.data : [];
      _error = res.success ? '' : (res.error ?? 'Erreur');
    });
  }

  // ── Recherche par nom de produit ─────────────────────────────
  Future<void> _searchByProduct(String pname) async {
    if (pname.isEmpty) {
      _loadData();
      return;
    }
    setState(() => _loading = true);
    final res =
        await _api.get('/stock-movement/search/product/$pname');
    // Guard: widget may have been disposed while waiting
    if (!mounted) return;
    setState(() {
      _loading = false;
      _movements =
          (res.success && res.data is List) ? res.data : [];
      _error = res.success ? '' : (res.error ?? 'Aucun résultat');
    });
  }

  // ── Mouvements filtrés localement ────────────────────────────
  List<dynamic> get _filtered {
    var list = _movements;
    if (_typeFilter != null) {
      list = list
          .where((m) => m['typemovement'] == _typeFilter)
          .toList();
    }
    return list;
  }

  // ── Supprimer un mouvement ───────────────────────────────────
  Future<void> _delete(int id) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer le mouvement',
      message: 'Supprimer ce mouvement de stock ?',
      confirmText: 'Supprimer',
    );
    if (ok != true) return;
    final res = await _api.delete('/stock-movement/delete/$id');
    if (!mounted) return;
    res.success
        ? showSuccess(context, 'Mouvement supprimé')
        : showError(context, res.error ?? 'Erreur');
    if (res.success) _loadData();
  }

  // ── Ouvrir dialog créer/modifier ─────────────────────────────
  void _openForm([dynamic movement]) {
    showDialog(
      context: context,
      builder: (_) => _StockMovementDialog(
        movement: movement,
        products: _products,
        reasons: kReasons,
        onSaved: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            color: kCardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: "Mouvements de Stock",
                  subtitle:
                      "${_movements.length} mouvement(s) enregistré(s)",
                  action: ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Nouveau mouvement"),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Barre de recherche ────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: _searchByProduct,
                        decoration: InputDecoration(
                          hintText:
                              "Rechercher par nom de produit...",
                          prefixIcon: const Icon(Icons.search,
                              color: kTextSecondary, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18,
                                      color: kTextSecondary),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadData();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bouton recherche
                    ElevatedButton(
                      onPressed: () =>
                          _searchByProduct(_searchCtrl.text.trim()),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
                      child: const Text("Chercher"),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── TabBar filtre type ────────────────────────
                TabBar(
                  controller: _tabController,
                  labelColor: kPrimary,
                  unselectedLabelColor: kTextSecondary,
                  indicatorColor: kPrimary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: "Tous"),
                    Tab(
                      icon: Icon(Icons.arrow_downward,
                          color: kSuccessColor, size: 14),
                      text: "Entrées (in)",
                    ),
                    Tab(
                      icon: Icon(Icons.arrow_upward,
                          color: kErrorColor, size: 14),
                      text: "Sorties (out)",
                    ),
                  ],
                  onTap: (i) {
                    setState(() => _typeFilter =
                        i == 0 ? null : (i == 1 ? 'in' : 'out'));
                    if (i == 0) {
                      _loadData();
                    } else {
                      _loadByType(i == 1 ? 'in' : 'out');
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Résumé rapide (2 cartes) ─────────────────────────
          _buildSummaryCards(),

          // ── Tableau mouvements ────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoader()
                : _error.isNotEmpty
                    ? ErrorMessage(
                        message: _error, onRetry: _loadData)
                    : _filtered.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.swap_vert_outlined,
                                    color: kTextSecondary,
                                    size: 52),
                                SizedBox(height: 12),
                                Text(
                                    "Aucun mouvement de stock enregistré",
                                    style: TextStyle(
                                        color: kTextSecondary)),
                              ],
                            ),
                          )
                        : _buildTable(),
          ),
        ],
      ),
    );
  }

  // ── Cartes résumé entrées / sorties ─────────────────────────
  Widget _buildSummaryCards() {
    final entries =
        _movements.where((m) => m['typemovement'] == 'in').length;
    final exits =
        _movements.where((m) => m['typemovement'] == 'out').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = (constraints.maxWidth - 16) / 2;
        return Row(
          children: [
            SizedBox(
              width: w,
              child: StatCard(
                title: "Entrées de stock",
                value: "$entries",
                icon: Icons.arrow_downward_outlined,
                color: kSuccessColor,
                subtitle: "Réapprovisionnements",
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: w,
              child: StatCard(
                title: "Sorties de stock",
                value: "$exits",
                icon: Icons.arrow_upward_outlined,
                color: kErrorColor,
                subtitle: "Consommations / Pertes",
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Tableau des mouvements ────────────────────────────────────
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
                  Expanded(flex: 1, child: _TH("ID")),
                  Expanded(flex: 2, child: _TH("Produit")),
                  Expanded(flex: 1, child: _TH("Qté")),
                  Expanded(flex: 1, child: _TH("Type")),
                  Expanded(flex: 2, child: _TH("Raison")),
                  Expanded(flex: 2, child: _TH("Date")),
                  Expanded(flex: 1, child: _TH("Actions")),
                ],
              ),
            ),

            // Lignes
            ..._filtered.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final isIn = m['typemovement'] == 'in';

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
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
                    // ID
                    Expanded(
                      flex: 1,
                      child: Text(
                        "#${m['id']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                            fontSize: 13),
                      ),
                    ),

                    // Produit
                    Expanded(
                      flex: 2,
                      child: Text(
                        m['product'] ?? '-',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Quantité
                    Expanded(
                      flex: 1,
                      child: Text(
                        "${m['quantity']}",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isIn
                                ? kSuccessColor
                                : kErrorColor),
                      ),
                    ),

                    // Type badge
                    Expanded(
                      flex: 1,
                      child: StatusBadge(
                        label: isIn ? "Entrée" : "Sortie",
                        color: isIn ? kSuccessColor : kErrorColor,
                      ),
                    ),

                    // Raison
                    Expanded(
                      flex: 2,
                      child: Text(
                        _reasonLabel(m['reason']),
                        style: const TextStyle(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ),

                    // Date
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(m['createdAt']),
                        style: const TextStyle(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ),

                    // Actions
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: kInfoColor),
                            onPressed: () => _openForm(m),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outlined,
                                size: 16, color: kErrorColor),
                            onPressed: () =>
                                _delete(m['id'] is int ? m['id'] as int : int.tryParse(m['id'].toString()) ?? 0),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
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

  String _reasonLabel(dynamic reason) {
    final r = kReasons.firstWhere(
      (e) => e['value'] == reason,
      orElse: () => {'label': reason?.toString() ?? '-'},
    );
    return r['label'] ?? '-';
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    final s = d.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

// ═══════════════════════════════════════════════════════════════
// DIALOG — Créer / Modifier un mouvement de stock
// ═══════════════════════════════════════════════════════════════
class _StockMovementDialog extends StatefulWidget {
  final dynamic movement;
  final List<dynamic> products;
  final List<Map<String, String>> reasons;
  final VoidCallback onSaved;

  const _StockMovementDialog({
    this.movement,
    required this.products,
    required this.reasons,
    required this.onSaved,
  });

  @override
  State<_StockMovementDialog> createState() =>
      _StockMovementDialogState();
}

class _StockMovementDialogState extends State<_StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();

  int? _selectedProductId;
  String _selectedType = 'in';
  String _selectedReason = 'purchase';
  bool _saving = false;

  bool get _isEdit => widget.movement != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final m = widget.movement;
      _qtyCtrl.text = (m['quantity'] ?? '').toString();
      _selectedType = m['typemovement'] ?? 'in';
      _selectedReason = m['reason'] ?? 'purchase';
      // Trouver l'ID du produit dans la liste
      final productName = m['product'];
      final found = widget.products.firstWhere(
        (p) => p['productname'] == productName,
        orElse: () => null,
      );
      if (found != null) _selectedProductId = found['id'] is int ? found['id'] as int : int.tryParse(found['id'].toString()) ?? 0;
    } else {
      _selectedReason = 'purchase';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ── Raisons filtrées selon le type ──────────────────────────
  List<Map<String, String>> get _filteredReasons {
    if (_selectedType == 'in') {
      return widget.reasons
          .where((r) => ['purchase', 'transfer_in', 'return', 'adjustment', 'other']
              .contains(r['value']))
          .toList();
    } else {
      return widget.reasons
          .where((r) => ['sale', 'transfer_out', 'loss', 'adjustment', 'other']
              .contains(r['value']))
          .toList();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      showError(context, 'Sélectionnez un produit');
      return;
    }

    setState(() => _saving = true);
    final api = ApiService();
    final body = {
      'product': _selectedProductId,
      'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
      'typemovement': _selectedType,
      'reason': _selectedReason,
    };

    final res = _isEdit
        ? await api.put(
            '/stock-movement/modify/${widget.movement['id']}', body)
        : await api.post('/stock-movement/create', body);

    setState(() => _saving = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(
          context,
          _isEdit
              ? 'Mouvement modifié'
              : 'Mouvement de stock créé');
      widget.onSaved();
      Navigator.pop(context);
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEdit
            ? 'Modifier le mouvement'
            : 'Nouveau mouvement de stock',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Type de mouvement ─────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Type de mouvement",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = 'in';
                          _selectedReason = 'purchase';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'in'
                              ? kSuccessColor
                              : kBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedType == 'in'
                                ? kSuccessColor
                                : kBorderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward,
                                size: 16,
                                color: _selectedType == 'in'
                                    ? Colors.white
                                    : kSuccessColor),
                            const SizedBox(width: 6),
                            Text(
                              "Entrée",
                              style: TextStyle(
                                color: _selectedType == 'in'
                                    ? Colors.white
                                    : kTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = 'out';
                          _selectedReason = 'sale';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'out'
                              ? kErrorColor
                              : kBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedType == 'out'
                                ? kErrorColor
                                : kBorderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward,
                                size: 16,
                                color: _selectedType == 'out'
                                    ? Colors.white
                                    : kErrorColor),
                            const SizedBox(width: 6),
                            Text(
                              "Sortie",
                              style: TextStyle(
                                color: _selectedType == 'out'
                                    ? Colors.white
                                    : kTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Produit ───────────────────────────────────
              DropdownButtonFormField<int>(
                value: _selectedProductId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Produit *",
                  prefixIcon: const Icon(Icons.inventory_2_outlined,
                      color: kTextSecondary, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: widget.products
                    .map((p) => DropdownMenuItem<int>(
                          value: p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0,
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      p['productname'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 13))),
                              Text(
                                "Stock: ${p['quantity']}",
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedProductId = v),
                validator: (v) =>
                    v == null ? 'Sélectionnez un produit' : null,
              ),
              const SizedBox(height: 14),

              // ── Quantité ──────────────────────────────────
              AppTextField(
                label: "Quantité *",
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.numbers_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  if (int.tryParse(v) == null || int.parse(v) <= 0)
                    return 'Entrez un nombre positif';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Raison ────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _filteredReasons
                        .any((r) => r['value'] == _selectedReason)
                    ? _selectedReason
                    : _filteredReasons.first['value'],
                decoration: InputDecoration(
                  labelText: "Raison *",
                  prefixIcon: const Icon(Icons.info_outline,
                      color: kTextSecondary, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _filteredReasons
                    .map((r) => DropdownMenuItem<String>(
                          value: r['value'],
                          child: Text(r['label']!,
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedReason = v!),
              ),

              // ── Infos stock produit sélectionné ───────────
              if (_selectedProductId != null) ...[
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  final product = widget.products.firstWhere(
                    (p) => p['id'] == _selectedProductId,
                    orElse: () => {},
                  );
                  if (product.isEmpty) return const SizedBox();
                  final stock = product['quantity'] ?? 0;
                  final minStock = product['minimumstock'] ?? 0;
                  final isLow = stock <= minStock;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLow
                          ? kErrorColor.withOpacity(0.08)
                          : kSuccessColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isLow
                              ? kErrorColor.withOpacity(0.3)
                              : kSuccessColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLow
                              ? Icons.warning_amber_outlined
                              : Icons.check_circle_outline,
                          color:
                              isLow ? kErrorColor : kSuccessColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Stock actuel : $stock  |  Stock min : $minStock",
                          style: TextStyle(
                              fontSize: 12,
                              color: isLow
                                  ? kErrorColor
                                  : kSuccessColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedType == 'in'
                ? kSuccessColor
                : kErrorColor,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(_isEdit ? 'Modifier' : 'Enregistrer'),
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