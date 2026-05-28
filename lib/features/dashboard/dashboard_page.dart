import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

// ═══════════════════════════════════════════════════════════════
// DASHBOARD — Toutes les statistiques de ventes
//
// Endpoints utilisés :
//   GET /api/v1/sale_history/period        → par période
//   GET /api/v1/sale_history/all           → toutes les ventes
//   GET /api/v1/sale_history/teller        → par caissier
//   GET /api/v1/sale_history/categoryToSale → par catégorie
//   GET /api/v1/sale_history/product        → par produit
//   GET /api/v1/user/list                  → liste caissiers
//   GET /api/v1/category/list              → liste catégories
//   GET /api/v1/product/list               → liste produits
// ═══════════════════════════════════════════════════════════════
// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL HELPERS — available to all classes in this file
// These handle Symfony responses where numbers can be int, double, or String
// ─────────────────────────────────────────────────────────────────────────────

// Safe price display: handles null, int, double, String "1123"
String _safePrice(dynamic val) {
  if (val == null) return '0 FCFA';
  if (val is num) return '${val.toStringAsFixed(0)} FCFA';
  final parsed = double.tryParse(val.toString());
  if (parsed != null) return '${parsed.toStringAsFixed(0)} FCFA';
  return '0 FCFA';
}

// Safe number formatter: returns formatted string
String _fmt(dynamic val) {
  if (val == null) return '0';
  if (val is num) return val.toStringAsFixed(0);
  final parsed = double.tryParse(val.toString());
  if (parsed != null) return parsed.toStringAsFixed(0);
  return '0';
}

// Safe double converter
double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  // ── Onglets du dashboard ─────────────────────────────────────
  late TabController _tabController;

  // ── Infos utilisateur ────────────────────────────────────────
  String _companyName = '';
  String _userName = '';

  // ── Données partagées ────────────────────────────────────────
  List<dynamic> _users = [];
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  bool _loadingMeta = true;

  // ── Tab 1 : Par période ──────────────────────────────────────
  String _selectedPeriod = 'today';
  Map<String, dynamic>? _periodStats;
  bool _loadingPeriod = false;
  String _periodError = '';

  // ── Tab 2 : Toutes les ventes ────────────────────────────────
  Map<String, dynamic>? _allStats;
  bool _loadingAll = false;
  String _allError = '';

  // ── Tab 3 : Par caissier ─────────────────────────────────────
  int? _selectedTellerId;
  Map<String, dynamic>? _tellerStats;
  bool _loadingTeller = false;
  String _tellerError = '';

  // ── Tab 4 : Par catégorie ────────────────────────────────────
  int? _selectedCategoryId;
  Map<String, dynamic>? _categoryStats;
  bool _loadingCategory = false;
  String _categoryError = '';

  // ── Tab 5 : Par produit ──────────────────────────────────────
  int? _selectedProductId;
  Map<String, dynamic>? _productStats;
  bool _loadingProduct = false;
  String _productError = '';

  final List<Map<String, String>> _periods = [
    {'key': 'today', 'label': "Aujourd'hui"},
    {'key': 'yesterday', 'label': 'Hier'},
    {'key': 'this_week', 'label': 'Cette semaine'},
    {'key': 'this_month', 'label': 'Ce mois'},
    {'key': 'this_year', 'label': 'Cette année'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInfo();
    _loadMeta();
    _loadPeriodStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Charger infos utilisateur ────────────────────────────────
  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString(kCompanyName) ?? 'Mon Restaurant';
      _userName = prefs.getString(kUserName) ?? 'Utilisateur';
    });
  }

  // ── Charger les listes (caissiers, catégories, produits) ─────
  Future<void> _loadMeta() async {
    setState(() => _loadingMeta = true);
    final results1 = await Future.wait([
      _api.get('/user/list'),
      _api.get('/category/list'),
      _api.get('/product/list'),
    ]);
    setState(() {
      _loadingMeta = false;
      _users = (results1[0].success && results1[0].data is List) ? results1[0].data : [];
      _categories = (results1[1].success && results1[1].data is List) ? results1[1].data : [];
      _products = (results1[2].success && results1[2].data is List) ? results1[2].data : [];
    });
  }

  // ── Réagir au changement d'onglet ────────────────────────────
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        if (_periodStats == null) _loadPeriodStats();
        break;
      case 1:
        if (_allStats == null) _loadAllStats();
        break;
      // Les onglets 2, 3, 4 se chargent sur sélection
    }
  }

  // ── TAB 1: Charger stats par période ─────────────────────────
  Future<void> _loadPeriodStats() async {
    setState(() {
      _loadingPeriod = true;
      _periodError = '';
    });
    // Symfony route is GET but reads JSON body via json_decode($request->getContent())
    // We use getWithBody() which sends GET + JSON body
    final res = await _api.getWithBody('/sale_history/period', {
      'period': _selectedPeriod,
    });
    setState(() {
      _loadingPeriod = false;
      if (res.success && res.data is Map) {
        _periodStats = Map<String, dynamic>.from(res.data);
      } else {
        _periodError = res.error ?? 'Aucune vente pour cette période';
        _periodStats = null;
      }
    });
  }

  // ── TAB 2: Charger toutes les ventes ─────────────────────────
  Future<void> _loadAllStats() async {
    setState(() {
      _loadingAll = true;
      _allError = '';
    });
    final res = await _api.get('/sale_history/all');
    setState(() {
      _loadingAll = false;
      if (res.success && res.data is Map) {
        _allStats = Map<String, dynamic>.from(res.data);
      } else {
        _allError = res.error ?? 'Aucune vente trouvée';
        _allStats = null;
      }
    });
  }

  // ── TAB 3: Charger stats par caissier ────────────────────────
  Future<void> _loadTellerStats() async {
    if (_selectedTellerId == null) return;
    setState(() {
      _loadingTeller = true;
      _tellerError = '';
    });
    // GET + JSON body
    final res = await _api.getWithBody('/sale_history/teller', {
      'teller_id': _selectedTellerId,
    });
    setState(() {
      _loadingTeller = false;
      if (res.success && res.data is Map) {
        _tellerStats = Map<String, dynamic>.from(res.data);
      } else {
        _tellerError = res.error ?? 'Aucune vente pour ce caissier';
        _tellerStats = null;
      }
    });
  }

  // ── TAB 4: Charger stats par catégorie ───────────────────────
  Future<void> _loadCategoryStats() async {
    if (_selectedCategoryId == null) return;
    setState(() {
      _loadingCategory = true;
      _categoryError = '';
    });
    // GET + JSON body
    final res = await _api.getWithBody('/sale_history/categoryToSale', {
      'categoryId': _selectedCategoryId,
    });
    setState(() {
      _loadingCategory = false;
      if (res.success && res.data is Map) {
        _categoryStats = Map<String, dynamic>.from(res.data);
      } else {
        _categoryError = res.error ?? 'Aucune vente pour cette catégorie';
        _categoryStats = null;
      }
    });
  }

  // ── TAB 5: Charger stats par produit ─────────────────────────
  Future<void> _loadProductStats() async {
    if (_selectedProductId == null) return;
    setState(() {
      _loadingProduct = true;
      _productError = '';
    });
    // GET + JSON body
    final res = await _api.getWithBody('/sale_history/product', {
      'productId': _selectedProductId,
    });
    setState(() {
      _loadingProduct = false;
      if (res.success && res.data is Map) {
        _productStats = Map<String, dynamic>.from(res.data);
      } else {
        _productError = res.error ?? 'Aucune vente pour ce produit';
        _productStats = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            color: kCardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bonjour, $_userName 👋",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                            ),
                          ),
                          Text(
                            _companyName,
                            style: const TextStyle(
                                color: kTextSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Bouton refresh
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined,
                          color: kPrimary),
                      tooltip: "Actualiser",
                      onPressed: () {
                        _loadMeta();
                        switch (_tabController.index) {
                          case 0: _loadPeriodStats(); break;
                          case 1: _loadAllStats(); break;
                          case 2: _loadTellerStats(); break;
                          case 3: _loadCategoryStats(); break;
                          case 4: _loadProductStats(); break;
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── TabBar ────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: kPrimary,
                  unselectedLabelColor: kTextSecondary,
                  indicatorColor: kPrimary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.date_range_outlined, size: 18),
                      text: "Par période",
                    ),
                    Tab(
                      icon: Icon(Icons.bar_chart_outlined, size: 18),
                      text: "Toutes les ventes",
                    ),
                    Tab(
                      icon: Icon(Icons.person_outlined, size: 18),
                      text: "Par caissier",
                    ),
                    Tab(
                      icon: Icon(Icons.category_outlined, size: 18),
                      text: "Par catégorie",
                    ),
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: "Par produit",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── TabBarView ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Par période ───────────────────────
                _TabPeriod(
                  periods: _periods,
                  selectedPeriod: _selectedPeriod,
                  stats: _periodStats,
                  loading: _loadingPeriod,
                  error: _periodError,
                  onPeriodChanged: (p) {
                    setState(() {
                      _selectedPeriod = p;
                      _periodStats = null;
                    });
                    _loadPeriodStats();
                  },
                  onRetry: _loadPeriodStats,
                ),

                // ── Tab 2: Toutes les ventes ─────────────────
                _TabAllSales(
                  stats: _allStats,
                  loading: _loadingAll,
                  error: _allError,
                  onLoad: _loadAllStats,
                  onRetry: _loadAllStats,
                ),

                // ── Tab 3: Par caissier ──────────────────────
                _TabByFilter(
                  title: "Sélectionnez un caissier",
                  icon: Icons.person_outline,
                  dropdownHint: "Choisir un caissier",
                  items: _users
                      .where((u) => u['id'] != null)
                      .map((u) => _FilterItem(
                            id: u['id'] is int
                                ? u['id'] as int
                                : int.tryParse(u['id'].toString()) ?? 0,
                            label: u['name'] ?? '',
                            subtitle: u['roles'] is List &&
                                    (u['roles'] as List).isNotEmpty
                                ? (u['roles'] as List).first.toString()
                                : '',
                          ))
                      .toList(),
                  selectedId: _selectedTellerId,
                  stats: _tellerStats,
                  loading: _loadingTeller,
                  error: _tellerError,
                  loadingMeta: _loadingMeta,
                  onSelected: (id) {
                    setState(() {
                      _selectedTellerId = id;
                      _tellerStats = null;
                    });
                    _loadTellerStats();
                  },
                  onRetry: _loadTellerStats,
                ),

                // ── Tab 4: Par catégorie ─────────────────────
                _TabByFilter(
                  title: "Sélectionnez une catégorie",
                  icon: Icons.category_outlined,
                  dropdownHint: "Choisir une catégorie",
                  items: _categories
                      // where: skip items with null id to avoid crash
                      .where((c) => c['id'] != null)
                      .map((c) => _FilterItem(
                            // int.tryParse handles both int and String ids
                            id: c['id'] is int
                                ? c['id'] as int
                                : int.tryParse(c['id'].toString()) ?? 0,
                            label: c['categoryname'] ?? '',
                            subtitle: c['description'] ?? '',
                          ))
                      .toList(),
                  selectedId: _selectedCategoryId,
                  stats: _categoryStats,
                  loading: _loadingCategory,
                  error: _categoryError,
                  loadingMeta: _loadingMeta,
                  onSelected: (id) {
                    setState(() {
                      _selectedCategoryId = id;
                      _categoryStats = null;
                    });
                    _loadCategoryStats();
                  },
                  onRetry: _loadCategoryStats,
                ),

                // ── Tab 5: Par produit ───────────────────────
                _TabByFilter(
                  title: "Sélectionnez un produit",
                  icon: Icons.inventory_2_outlined,
                  dropdownHint: "Choisir un produit",
                  items: _products
                      // where: skip items with null id
                      .where((p) => p['id'] != null)
                      .map((p) => _FilterItem(
                            id: p['id'] is int
                                ? p['id'] as int
                                : int.tryParse(p['id'].toString()) ?? 0,
                            label: p['productname'] ?? '',
                            // Safe price display — handles null and String values
                            subtitle: _safePrice(p['saleprice']),
                          ))
                      .toList(),
                  selectedId: _selectedProductId,
                  stats: _productStats,
                  loading: _loadingProduct,
                  error: _productError,
                  loadingMeta: _loadingMeta,
                  onSelected: (id) {
                    setState(() {
                      _selectedProductId = id;
                      _productStats = null;
                    });
                    _loadProductStats();
                  },
                  onRetry: _loadProductStats,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MODÈLE ITEM FILTRE (caissier / catégorie / produit)
// ═══════════════════════════════════════════════════════════════
class _FilterItem {
  final int id;
  final String label;
  final String subtitle;
  const _FilterItem(
      {required this.id, required this.label, required this.subtitle});
}

// ═══════════════════════════════════════════════════════════════
// WIDGET CARTES KPI — Réutilisé dans tous les onglets
// ═══════════════════════════════════════════════════════════════
class _StatsKpiSection extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsKpiSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Use _toDouble() to safely handle String numbers from Symfony
    final totalSales     = _toDouble(stats['total_sales']);
    final totalPurchases = _toDouble(stats['total_purchases']);
    final profit         = _toDouble(stats['profit']);
    final sales = (stats['sales'] as List?) ?? [];
    final isProfit = profit >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 4 cartes KPI ────────────────────────────────────
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900
              ? 4
              : constraints.maxWidth > 600
                  ? 2
                  : 1;
          final itemW =
              (constraints.maxWidth - (crossCount - 1) * 16) / crossCount;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: itemW,
                child: StatCard(
                  title: "Chiffre d'affaires",
                  value: "${_fmt(totalSales)} FCFA",
                  icon: Icons.trending_up,
                  color: kSuccessColor,
                  subtitle: "${sales.length} vente(s)",
                ),
              ),
              SizedBox(
                width: itemW,
                child: StatCard(
                  title: "Coût d'achat",
                  value: "${_fmt(totalPurchases)} FCFA",
                  icon: Icons.shopping_cart_outlined,
                  color: kInfoColor,
                ),
              ),
              SizedBox(
                width: itemW,
                child: StatCard(
                  title: "Bénéfice net",
                  value: "${_fmt(profit)} FCFA",
                  icon: Icons.account_balance_wallet_outlined,
                  color: isProfit ? kSuccessColor : kErrorColor,
                  subtitle: isProfit ? "✓ Positif" : "✗ Négatif",
                ),
              ),
              SizedBox(
                width: itemW,
                child: StatCard(
                  title: "Nb. transactions",
                  value: "${sales.length}",
                  icon: Icons.receipt_outlined,
                  color: kWarningColor,
                ),
              ),
            ],
          );
        }),

        const SizedBox(height: 24),

        // ── Tableau des ventes ───────────────────────────────
        if (sales.isNotEmpty) ...[
          const Text(
            "Détail des ventes",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextPrimary),
          ),
          const SizedBox(height: 10),
          _SalesTable(sales: sales),
        ] else
          _EmptySales(),
      ],
    );
  }

  // Helpers moved to top-level functions (see top of file)
}

// ═══════════════════════════════════════════════════════════════
// TABLEAU DES VENTES
// ═══════════════════════════════════════════════════════════════
class _SalesTable extends StatelessWidget {
  final List<dynamic> sales;
  const _SalesTable({required this.sales});

  @override
  Widget build(BuildContext context) {
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
          // En-tête
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Expanded(flex: 2, child: _TH("Caissier")),
                Expanded(flex: 2, child: _TH("Date")),
                Expanded(flex: 3, child: _TH("Produits vendus")),
              ],
            ),
          ),
          // Lignes
          ...sales.take(15).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final sale = entry.value;
            final products = (sale['products'] as List?) ?? [];

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color:
                    i % 2 == 0 ? kCardBg : kBackground.withOpacity(0.5),
                border: Border(
                    top: BorderSide(
                        color: kBorderColor.withOpacity(0.4))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "#${sale['id']}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                          fontSize: 13),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: kPrimary.withOpacity(0.12),
                          child: Text(
                            (sale['teller']?.toString() ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                                color: kPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sale['teller']?.toString() ?? '-',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(sale['date_created']),
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: products.isEmpty
                        ? const Text("-",
                            style: TextStyle(
                                fontSize: 12, color: kTextSecondary))
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: products.take(3).map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kPrimary.withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${p['product_name'] ?? ''} ×${p['quantity'] ?? 1}",
                                  style: const TextStyle(
                                      fontSize: 11, color: kPrimary),
                                ),
                              );
                            }).toList(),
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

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    final s = d.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

// ── Widget état vide ─────────────────────────────────────────
class _EmptySales extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: kTextSecondary, size: 48),
            SizedBox(height: 12),
            Text("Aucune vente trouvée",
                style: TextStyle(color: kTextSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — PAR PÉRIODE
// ═══════════════════════════════════════════════════════════════
class _TabPeriod extends StatelessWidget {
  final List<Map<String, String>> periods;
  final String selectedPeriod;
  final Map<String, dynamic>? stats;
  final bool loading;
  final String error;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onRetry;

  const _TabPeriod({
    required this.periods,
    required this.selectedPeriod,
    required this.stats,
    required this.loading,
    required this.error,
    required this.onPeriodChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sélecteur période
          Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8)
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: periods.map((p) {
                  final isSelected = p['key'] == selectedPeriod;
                  return GestureDetector(
                    onTap: () => onPeriodChanged(p['key']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : kTextSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (loading)
            const AppLoader()
          else if (error.isNotEmpty)
            ErrorMessage(message: error, onRetry: onRetry)
          else if (stats != null)
            _StatsKpiSection(stats: stats!)
          else
            const AppLoader(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — TOUTES LES VENTES
// ═══════════════════════════════════════════════════════════════
class _TabAllSales extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool loading;
  final String error;
  final VoidCallback onLoad;
  final VoidCallback onRetry;

  const _TabAllSales({
    required this.stats,
    required this.loading,
    required this.error,
    required this.onLoad,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Charger au premier affichage si pas encore chargé
    if (stats == null && !loading && error.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoad());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre section
          Row(
            children: [
              const Icon(Icons.bar_chart, color: kPrimary, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Vue globale — Toutes les ventes",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_outlined,
                    color: kPrimary, size: 20),
                onPressed: onLoad,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (loading)
            const AppLoader()
          else if (error.isNotEmpty)
            ErrorMessage(message: error, onRetry: onRetry)
          else if (stats != null)
            _StatsKpiSection(stats: stats!)
          else
            const AppLoader(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3, 4, 5 — PAR FILTRE (caissier / catégorie / produit)
// ═══════════════════════════════════════════════════════════════
class _TabByFilter extends StatelessWidget {
  final String title;
  final IconData icon;
  final String dropdownHint;
  final List<_FilterItem> items;
  final int? selectedId;
  final Map<String, dynamic>? stats;
  final bool loading;
  final String error;
  final bool loadingMeta;
  final ValueChanged<int> onSelected;
  final VoidCallback onRetry;

  const _TabByFilter({
    required this.title,
    required this.icon,
    required this.dropdownHint,
    required this.items,
    required this.selectedId,
    required this.stats,
    required this.loading,
    required this.error,
    required this.loadingMeta,
    required this.onSelected,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sélecteur dropdown ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: kPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                loadingMeta
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: kPrimary, strokeWidth: 2),
                        ),
                      )
                    : items.isEmpty
                        ? Text(
                            "Aucun élément disponible",
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 13),
                          )
                        : DropdownButtonFormField<int>(
                            value: selectedId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: dropdownHint,
                              prefixIcon: Icon(icon,
                                  color: kTextSecondary, size: 18),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                            ),
                            items: items
                                .map((item) => DropdownMenuItem<int>(
                                      value: item.id,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(item.label,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          if (item.subtitle.isNotEmpty)
                                            Text(item.subtitle,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        kTextSecondary)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) onSelected(v);
                            },
                          ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Résultats ──────────────────────────────────────
          if (selectedId == null)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(icon,
                        color: kTextSecondary.withOpacity(0.4),
                        size: 52),
                    const SizedBox(height: 12),
                    Text(
                      dropdownHint,
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else if (loading)
            const AppLoader()
          else if (error.isNotEmpty)
            ErrorMessage(message: error, onRetry: onRetry)
          else if (stats != null)
            _StatsKpiSection(stats: stats!)
          else
            const AppLoader(),
        ],
      ),
    );
  }
}

// ── En-tête de colonne tableau ───────────────────────────────
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