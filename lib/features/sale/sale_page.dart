import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';
import '../../core/role_guard.dart';

// ═══════════════════════════════════════════════════════════════
// PAGE VENTES
// GET  /api/v1/sale_history/all        — lister toutes les ventes
// POST /api/v1/checkout/sale           — valider une commande en vente
// POST /api/v1/checkout/cancelsale     — annuler une vente
// ═══════════════════════════════════════════════════════════════
class SalePage extends StatefulWidget {
  const SalePage({super.key});

  @override
  State<SalePage> createState() => _SalePageState();
}

class _SalePageState extends State<SalePage> {
  final _api = ApiService();
  List<dynamic> _sales = [];
  bool _loading = true;
  String _error = '';

  // Pour valider une commande existante en vente
  final _orderIdCtrl = TextEditingController();
  // Payment method — selected from dropdown, not typed manually
  // Matches the paymentMethod values expected by Symfony CheckoutService
  String _selectedPayment = 'Cash';

  // Available payment methods shown in the dropdown
  static const List<Map<String, dynamic>> _paymentMethods = [
    {'value': 'Cash',          'label': 'Espèces',        'icon': Icons.money},
    {'value': 'Card',          'label': 'Carte bancaire', 'icon': Icons.credit_card_outlined},
    {'value': 'Mobile Money',  'label': 'Mobile Money',   'icon': Icons.phone_android_outlined},
    {'value': 'Orange Money',  'label': 'Orange Money',   'icon': Icons.account_balance_wallet_outlined},
    {'value': 'Wave',          'label': 'Wave',           'icon': Icons.waves_outlined},
    {'value': 'Transfer',      'label': 'Virement',       'icon': Icons.swap_horiz_outlined},
  ];
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    // _selectedPayment is a String — no controller to dispose
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);
    final res = await _api.get('/sale_history/all');
    // Guard: widget may have been disposed while waiting for the API response
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is Map) {
        _sales = res.data['sales'] ?? [];
        _error = '';
      } else {
        _error = res.error ?? 'Aucune vente trouvée';
        _sales = [];
      }
    });
  }

  // ── Valider commande → vente ─────────────────────────────────
  Future<void> _validateSale() async {
    if (_orderIdCtrl.text.isEmpty) {
      showError(context, 'Entrez un ID de commande');
      return;
    }
    setState(() => _validating = true);
    final res = await _api.post('/checkout/sale', {
      'customerOrderId': int.tryParse(_orderIdCtrl.text) ?? 0,
      // Send the selected payment method value to Symfony
      'paymentMethod': _selectedPayment,
    });
    setState(() => _validating = false);
    if (!mounted) return;

    if (res.success) {
      showSuccess(context, 'Vente enregistrée !');
      _orderIdCtrl.clear();
      _loadSales();
      Navigator.pop(context);
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Annuler la vente",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Veuillez indiquer la raison de l'annulation :"),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: kErrorColor),
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
      _loadSales();
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  // ── Ouvrir le dialog validation commande ─────────────────────
  void _showValidateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Valider une commande",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _orderIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID de la commande',
                prefixIcon: Icon(Icons.receipt_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // ── Payment method dropdown ──────────────────────────────
            // StatefulBuilder needed to update the dropdown inside AlertDialog
            // (AlertDialog is outside the main widget tree, setState won't work)
            StatefulBuilder(
              builder: (context, setDropState) {
                return DropdownButtonFormField<String>(
                  value: _selectedPayment,
                  decoration: const InputDecoration(
                    labelText: 'Mode de paiement',
                    prefixIcon: Icon(Icons.payment_outlined),
                    border: OutlineInputBorder(),
                  ),
                  // Build one item per payment method
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
                      // Update both the dialog state AND the parent state
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: _validating ? null : _validateSale,
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

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      route: '/sale',
      child: MainLayout(
      currentRoute: '/sale',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            color: kCardBg,
            child: PageHeader(
              title: "Ventes",
              subtitle: "${_sales.length} vente(s) enregistrée(s)",
              action: ElevatedButton.icon(
                onPressed: _showValidateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Valider commande"),
              ),
            ),
          ),

          // ── Tableau des ventes ────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoader()
                : _sales.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.point_of_sale_outlined,
                                color: kTextSecondary, size: 56),
                            SizedBox(height: 12),
                            Text("Aucune vente enregistrée",
                                style: TextStyle(
                                    color: kTextSecondary, fontSize: 15)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildSalesTable(),
                      ),
          ),
        ],
      ),
    )
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
          // En-tête tableau
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
                Expanded(
                    flex: 1,
                    child: _TableHeader("ID")),
                Expanded(
                    flex: 2,
                    child: _TableHeader("Caissier")),
                Expanded(
                    flex: 2,
                    child: _TableHeader("Date")),
                Expanded(
                    flex: 2,
                    child: _TableHeader("Produits")),
                Expanded(
                    flex: 1,
                    child: _TableHeader("Actions")),
              ],
            ),
          ),
          // Lignes
          ..._sales.asMap().entries.map((entry) {
            final i = entry.key;
            final sale = entry.value;
            final products = (sale['products'] as List?) ?? [];
            final isEven = i % 2 == 0;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven
                    ? kCardBg
                    : kBackground.withOpacity(0.5),
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
                          radius: 14,
                          backgroundColor:
                              kPrimary.withOpacity(0.12),
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
                      (sale['date_created'] ?? '')
                          .toString()
                          .substring(0, 10),
                      style: const TextStyle(
                          fontSize: 13, color: kTextSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: products.take(2).map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            p['product_name'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: kPrimary),
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
                      onPressed: () =>
                          _cancelSale(sale['id'] is int ? sale['id'] as int : int.tryParse(sale['id'].toString()) ?? 0),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );// RoleGuard
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
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: kTextSecondary),
    );
  }
}