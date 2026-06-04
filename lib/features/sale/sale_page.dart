import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';
import '../../core/role_guard.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE VENTES
// GET  /api/v1/sale_history/all            — lister toutes les ventes
// GET  /api/v1/checkout/pending-orders     — lister commandes en attente
// POST /api/v1/checkout/sale               — valider une commande en vente
// POST /api/v1/checkout/cancelsale         — annuler une vente
// ═══════════════════════════════════════════════════════════════
class SalePage extends StatefulWidget {
  const SalePage({super.key});

  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  final _api = ApiService();
  List<dynamic> _sales = [];
  List<dynamic> _pendingOrders = [];
  bool _loadingSales = true;
  bool _loadingOrders = true;
  String _error = '';

  // Payment method — selected from dropdown
  String _selectedPayment = 'Cash';

  // Available payment methods shown in the dropdown
  static const List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'Cash', 'label': 'Espèces', 'icon': Icons.money},
    {'value': 'Card', 'label': 'Carte bancaire', 'icon': Icons.credit_card_outlined},
    {'value': 'Mobile Money', 'label': 'Mobile Money', 'icon': Icons.phone_android_outlined},
    {'value': 'Orange Money', 'label': 'Orange Money', 'icon': Icons.account_balance_wallet_outlined},
    {'value': 'Wave', 'label': 'Wave', 'icon': Icons.waves_outlined},
    {'value': 'Transfer', 'label': 'Virement', 'icon': Icons.swap_horiz_outlined},
  ];

  bool _validating = false;
  int? _selectedOrderId;
  Map<String, dynamic>? _selectedOrderDetails;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingSales = true;
      _loadingOrders = true;
    });

    final results = await Future.wait([
      _api.get('/sale_history/all'),
      _api.get('/checkout/pending-orders'),
    ]);

    if (!mounted) return;
    setState(() {
      _loadingSales = false;
      _loadingOrders = false;

      // Sales
      if (results[0].success && results[0].data is Map) {
        _sales = results[0].data['sales'] ?? [];
      } else {
        _error = results[0].error ?? 'Erreur chargement ventes';
        _sales = [];
      }

      // Pending orders
      if (results[1].success && results[1].data is List) {
        _pendingOrders = results[1].data;
      } else {
        _pendingOrders = [];
      }
    });
  }

  // ── Valider commande sélectionnée → vente ─────────────────────────────────
  Future<void> _validateSale(int orderId) async {
    setState(() => _validating = true);
    final res = await _api.post('/checkout/sale', {
      'customerOrderId': orderId,
      'paymentMethod': _selectedPayment,
    });
    setState(() => _validating = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(context, 'Vente enregistrée !');
      _selectedOrderId = null;
      _selectedOrderDetails = null;
      _loadAll();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  // ── Annuler une vente ────────────────────────────────────────
  Future<void> _cancelSale(int saleId) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Annuler la vente",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Veuillez indiquer la raison de l'annulation :"),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => reason = v,
              decoration: const InputDecoration(
                hintText: 'Raison...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || reason.isEmpty) return;

    final res = await _api.post('/checkout/cancelsale', {
      'saleId': saleId,
      'reason': reason,
    });
    if (!mounted) return;
    if (res.success) {
      showSuccess(context, 'Vente annulée');
      _loadAll();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  // ── Ouvrir le dialog validation commande ─────────────────────
  void _showValidateDialog(int orderId, Map<String, dynamic> order) {
    _selectedOrderId = orderId;
    _selectedOrderDetails = order;
    _selectedPayment = 'Cash';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Valider la commande",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order details
            Text("Commande #$orderId",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Serveur: ${order['waiter'] ?? '-'}",
                style: const TextStyle(color: kTextSecondary)),
            Text("Date: ${(order['created_at'] ?? '').toString().substring(0, 16)}",
                style: const TextStyle(color: kTextSecondary)),
            Text("Total: ${(order['total_amount'] ?? 0).toStringAsFixed(0)} FCFA",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary)),
            Text("Articles: ${order['items_count'] ?? 0}",
                style: const TextStyle(color: kTextSecondary)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Payment method dropdown
            StatefulBuilder(
              builder: (context, setDropState) {
                return DropdownButtonFormField<String>(
                  value: _selectedPayment,
                  decoration: const InputDecoration(
                    labelText: 'Mode de paiement',
                    prefixIcon: Icon(Icons.payment_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentMethods.map((method) {
                    return DropdownMenuItem<String>(
                      value: method['value'] as String,
                      child: Row(
                        children: [
                          Icon(method['icon'] as IconData,
                              size: 18, color: kTextSecondary),
                          const SizedBox(width: 10),
                          Text(method['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDropState(() => _selectedPayment = val);
                      setState(() => _selectedPayment = val);
                    }
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                _selectedOrderId = null;
                _selectedOrderDetails = null;
                Navigator.pop(context);
              },
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: _validating ? null : () => _validateSale(_selectedOrderId!),
            child: _validating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Valider'),
          ),
        ],
      ),
    );
  }

  // ── Safe number conversion helper ────────────────────────────────────────
  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      route: '/sale',
      child: MainLayout(
        currentRoute: '/sale',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              color: kCardBg,
              child: Row(
                children: [
                  Expanded(
                    child: PageHeader(
                      title: "Ventes",
                      subtitle: "${_sales.length} vente(s)  •  ${_pendingOrders.length} commande(s) en attente",
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Actualiser"),
                  ),
                ],
              ),
            ),

            // ── Main content: Sales (left) + Pending Orders (right) ──────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── LEFT: Sales list ────────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 10, 20),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05), blurRadius: 8)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: kBackground,
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.point_of_sale_outlined,
                                    color: kPrimary, size: 20),
                                const SizedBox(width: 8),
                                Text("Ventes enregistrées (${_sales.length})",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                          ),
                          // Sales table
                          Expanded(
                            child: _loadingSales
                                ? const Center(child: AppLoader())
                                : _sales.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.point_of_sale_outlined,
                                                color: kTextSecondary, size: 48),
                                            SizedBox(height: 12),
                                            Text("Aucune vente enregistrée",
                                                style: TextStyle(
                                                    color: kTextSecondary, fontSize: 14)),
                                          ],
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: _buildSalesTable(),
                                      ),
                                      ),
                        ],
                      ),
                    ),
                  ),

                  // ── RIGHT: Pending orders ───────────────────────────────
                  Container(
                    width: 360,
                    margin: const EdgeInsets.fromLTRB(10, 0, 20, 20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05), blurRadius: 8)
                      ],
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kWarningColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pending_actions_outlined,
                                  color: kWarningColor, size: 20),
                              const SizedBox(width: 8),
                              Text("Commandes en attente (${_pendingOrders.length})",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: kWarningColor)),
                            ],
                          ),
                        ),
                        // Pending orders list
                        Expanded(
                          child: _loadingOrders
                              ? const Center(child: AppLoader())
                              : _pendingOrders.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline,
                                              color: kSuccessColor.withOpacity(0.5), size: 48),
                                          const SizedBox(height: 12),
                                          const Text("Aucune commande en attente",
                                              style: TextStyle(
                                                  color: kTextSecondary, fontSize: 14)),
                                          const SizedBox(height: 8),
                                          const Text("Les commandes validées apparaîtront ici",
                                              style: TextStyle(
                                                  color: kTextSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _pendingOrders.length,
                                      itemBuilder: (_, i) {
                                        final order = _pendingOrders[i];
                                        final id = order['id'] as int;
                                        final waiter = order['waiter'] ?? 'Serveur';
                                        final date = (order['created_at'] ?? '').toString().substring(0, 16);
                                        final total = _safeDouble(order['total_amount']);
                                        final itemsCount = order['items_count'] ?? 0;

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10)),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => _showValidateDialog(id, order),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Order header
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                            color: kWarningColor.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(6)),
                                                        child: Text("#$id",
                                                            style: const TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                color: kWarningColor,
                                                                fontSize: 13)),
                                                      ),
                                                      const Spacer(),
                                                      Text("${total.toStringAsFixed(0)} FCFA",
                                                          style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 15,
                                                              color: kPrimary)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Details
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.person_outline,
                                                          size: 14, color: kTextSecondary),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(waiter,
                                                            style: const TextStyle(
                                                                fontSize: 13,
                                                                color: kTextSecondary),
                                                            overflow: TextOverflow.ellipsis),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.access_time,
                                                          size: 14, color: kTextSecondary),
                                                      const SizedBox(width: 6),
                                                      Text(date,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color: kTextSecondary)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.shopping_bag_outlined,
                                                          size: 14, color: kTextSecondary),
                                                      const SizedBox(width: 6),
                                                      Text("$itemsCount article(s)",
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              color: kTextSecondary)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Action hint
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: kPrimary.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Center(
                                                      child: Text(
                                                        "Appuyer pour valider",
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: kPrimary),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTable() {
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
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 1, child: _TableHeader("ID")),
                Expanded(flex: 2, child: _TableHeader("Caissier")),
                Expanded(flex: 2, child: _TableHeader("Date")),
                Expanded(flex: 2, child: _TableHeader("Produits")),
                Expanded(flex: 1, child: _TableHeader("Actions")),
              ],
            ),
          ),
          // Rows
          ..._sales.asMap().entries.map((entry) {
            final i = entry.key;
            final sale = entry.value;
            final products = (sale['products'] as List?) ?? [];
            final isEven = i % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven ? kCardBg : kBackground.withOpacity(0.5),
                border: Border(
                    top: BorderSide(color: kBorderColor.withOpacity(0.4))),
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
                          radius: 14,
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
                      (sale['date_created'] ?? '').toString().substring(0, 10),
                      style: const TextStyle(fontSize: 13, color: kTextSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: products.take(2).map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p['product_name'] ?? '',
                            style: const TextStyle(fontSize: 11, color: kPrimary),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: kErrorColor, size: 18),
                      tooltip: "Annuler la vente",
                      onPressed: () => _cancelSale(
                          sale['id'] is int
                              ? sale['id'] as int
                              : int.tryParse(sale['id'].toString()) ?? 0),
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

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 12, color: kTextSecondary),
    );
  }
}