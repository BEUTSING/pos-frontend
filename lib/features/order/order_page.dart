// ─────────────────────────────────────────────────────────────────────────────
// FILE: order_page.dart
// PURPOSE: Order page — waiter selects products to create a customer order
//
// PRODUCT CARD shows:
//   - Product name (productname)
//   - Sale price (saleprice)
//   - Abbreviation = first 3 letters of the product name (e.g. "Pou" for Poulet)
//   - Quantity input: user types OR uses +/- buttons
//
// FLOW:
//   1. Products loaded from API → shown as cards grouped by category
//   2. Waiter taps a card → card is selected (highlighted green)
//   3. Waiter sets quantity (type or +/-)
//   4. Tap "Passer la commande" → POST /checkout/order
//   5. Order appears in the right panel
//   6. To cancel an item → POST /checkout/cancel (orderItemId)
//
// API CALLS:
//   GET  /api/v1/product/list      → load products
//   GET  /api/v1/category/list     → load categories for filter
//   POST /api/v1/checkout/order    → create or update order
//   POST /api/v1/checkout/cancel   → cancel one order item
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter
import '../../core/constants.dart';
import '../../core/api_service.dart';
import '../../core/widgets.dart';
import '../../core/main_layout.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _api = ApiService();

  // ── Data lists ────────────────────────────────────────────────────────────
  List<dynamic> _products   = []; // all products from API
  List<dynamic> _categories = []; // all categories from API
  bool   _loadingProducts   = true;
  String _error             = '';

  // ── Category filter — null = show all ────────────────────────────────────
  int? _selectedCategoryId;

  // ── Selected products: Map<productId, quantity> ───────────────────────────
  // When a card is tapped, its id is added here with quantity 1
  // Tapping again removes it (toggle)
  final Map<int, int> _selected = {};

  // ── Quantity text controllers: Map<productId, TextEditingController> ──────
  // Each selected product has its own text field for quantity input
  final Map<int, TextEditingController> _qtyControllers = {};

  // ── Current order state ───────────────────────────────────────────────────
  int?  _currentOrderId = null; // null = new order, not null = existing
  bool  _placingOrder   = false;
  List<dynamic> _orderItems = []; // items confirmed in the current order

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Always dispose text controllers to avoid memory leaks
    for (final ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Load products + categories from API ───────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loadingProducts = true);

    final results = await Future.wait([
      _api.get('/product/list'),
      _api.get('/category/list'),
    ]);

    if (!mounted) return;
    setState(() {
      _loadingProducts = false;
      _products   = (results[0].success && results[0].data is List)
          ? results[0].data : [];
      _categories = (results[1].success && results[1].data is List)
          ? results[1].data : [];
      _error = (!results[0].success) ? (results[0].error ?? 'Erreur') : '';
    });
  }

  // ── Filter products by selected category ─────────────────────────────────
  List<dynamic> get _filteredProducts {
    if (_selectedCategoryId == null) return _products;
    return _products.where((p) {
      final cat = p['category'];
      // category can be a String (name) or a Map {id, name}
      if (cat is Map) return cat['id'] == _selectedCategoryId;
      return false;
    }).toList();
  }

  // ── Get abbreviation — first 3 uppercase letters of product name ──────────
  // Example: "Poulet Rôti" → "POU"
  // Example: "Jus de Fruit" → "JUS"
  String _getAbbreviation(String name) {
    if (name.isEmpty) return '?';
    // Remove spaces and take first 3 characters, uppercase
    final clean = name.replaceAll(' ', '');
    return clean.substring(0, clean.length >= 3 ? 3 : clean.length)
        .toUpperCase();
  }

  // ── Toggle product selection ──────────────────────────────────────────────
  // First tap → select with quantity 1
  // Second tap → deselect and remove
  void _toggleProduct(int productId) {
    setState(() {
      if (_selected.containsKey(productId)) {
        // Deselect: remove from map and dispose its controller
        _selected.remove(productId);
        _qtyControllers[productId]?.dispose();
        _qtyControllers.remove(productId);
      } else {
        // Select: add with default quantity 1
        _selected[productId] = 1;
        // Create a text controller pre-filled with "1"
        _qtyControllers[productId] = TextEditingController(text: '1');
      }
    });
  }

  // ── Change quantity with +/- buttons ─────────────────────────────────────
  void _changeQty(int productId, int delta) {
    setState(() {
      final current = _selected[productId] ?? 1;
      final newQty  = current + delta;
      if (newQty <= 0) {
        // Remove if quantity goes to 0
        _selected.remove(productId);
        _qtyControllers[productId]?.dispose();
        _qtyControllers.remove(productId);
      } else {
        _selected[productId] = newQty;
        // Sync the text field with the new value
        _qtyControllers[productId]?.text = newQty.toString();
      }
    });
  }

  // ── Update quantity from text field input ─────────────────────────────────
  void _onQtyChanged(int productId, String value) {
    final qty = int.tryParse(value);
    if (qty != null && qty > 0) {
      setState(() => _selected[productId] = qty);
    } else if (value.isEmpty) {
      // Keep selected but with qty 0 temporarily while typing
      setState(() => _selected[productId] = 0);
    }
  }

  // ── Safe number conversion helper ────────────────────────────────────────
  // Symfony sometimes returns numbers as strings — handle both cases
  double _safeDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // ── Calculate total for selected items ───────────────────────────────────
  double get _total {
    double total = 0;
    for (final entry in _selected.entries) {
      final product = _products.firstWhere(
          (p) => p['id'] == entry.key,
          orElse: () => <String, dynamic>{});
      if (product.isNotEmpty) {
        total += _safeDouble(product['saleprice']) * entry.value;
      }
    }
    return total;
  }

  // ── Validate and submit the order ─────────────────────────────────────────
  Future<void> _validateOrder() async {
    // Filter out items with quantity 0 or less
    final validItems = _selected.entries
        .where((e) => e.value > 0)
        .toList();

    if (validItems.isEmpty) {
      showError(context, 'Sélectionnez au moins un produit');
      return;
    }

    setState(() => _placingOrder = true);

    // Build the items list expected by Symfony CheckoutService
    final items = validItems
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    // Build request body
    // If _currentOrderId is set, add items to existing order
    // Otherwise, create a new order
    final body = <String, dynamic>{'items': items};
    if (_currentOrderId != null) {
      body['customerOrderId'] = _currentOrderId;
    }

    final res = await _api.post('/checkout/order', body);
    setState(() => _placingOrder = false);
    if (!mounted) return;

    if (res.success) {
      // Parse the response from CheckoutService
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
      final orderId = data['order_id'];

      setState(() {
        _currentOrderId = orderId;
        // Save order items for display in right panel
        _orderItems = (data['items'] as List?) ?? [];
        // Clear selection after successful order
        _selected.clear();
        for (final ctrl in _qtyControllers.values) ctrl.dispose();
        _qtyControllers.clear();
      });

      showSuccess(context,
          'Commande #$orderId ${_currentOrderId == null ? "créée" : "mise à jour"} !');
    } else {
      showError(context, res.error ?? 'Erreur lors de la commande');
    }
  }

  // ── Cancel a specific order item ──────────────────────────────────────────
  Future<void> _cancelItem(int orderItemId, String productName) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Retirer l\'article',
      message: 'Retirer "$productName" de la commande #$_currentOrderId ?',
      confirmText: 'Retirer',
    );
    if (ok != true) return;

    final res = await _api.post('/checkout/cancel', {
      'orderItemId': orderItemId,
    });
    if (!mounted) return;

    if (res.success) {
      showSuccess(context, '"$productName" retiré de la commande');
      // Refresh order items from response
      final data = res.data;
      if (data is List && data.isNotEmpty) {
        final updated = data[0] as Map?;
        setState(() {
          _orderItems = (updated?['items'] as List?) ?? [];
          // If order is now empty, reset
          if (_orderItems.isEmpty) _currentOrderId = null;
        });
      }
    } else {
      showError(context, res.error ?? 'Erreur');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/order',
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // On wide screens: products on left, order summary on right
          final isWide = constraints.maxWidth > 750;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── LEFT PANEL: Product catalog ────────────────────────────
              Expanded(
                flex: 3,
                child: _loadingProducts
                    ? const AppLoader()
                    : _error.isNotEmpty
                        ? ErrorMessage(message: _error, onRetry: _loadData)
                        : _buildProductPanel(),
              ),

              // ── RIGHT PANEL: Order summary ─────────────────────────────
              // Always visible on desktop, only when items selected on mobile
              if (isWide || _selected.isNotEmpty || _orderItems.isNotEmpty)
                Container(
                  width: isWide ? 300 : double.infinity,
                  decoration: const BoxDecoration(
                    color: kCardBg,
                    border: Border(left: BorderSide(color: kBorderColor)),
                  ),
                  child: _buildOrderPanel(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT PANEL — product grid with category filter
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProductPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header + category filter ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          color: kCardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: "Nouvelle commande",
                subtitle: "${_filteredProducts.length} produit(s) disponible(s)",
              ),
              const SizedBox(height: 12),

              // Category chips — "Tous" + one chip per category
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "All" chip
                    _CategoryChip(
                      label: "Tous",
                      isSelected: _selectedCategoryId == null,
                      onTap: () =>
                          setState(() => _selectedCategoryId = null),
                    ),
                    // One chip per category
                    ..._categories.map((cat) => _CategoryChip(
                          label: cat['categoryname'] ?? '',
                          isSelected: _selectedCategoryId == cat['id'],
                          onTap: () => setState(
                              () => _selectedCategoryId = cat['id']),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Product grid ───────────────────────────────────────────────
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(
                  child: Text("Aucun produit dans cette catégorie",
                      style: TextStyle(color: kTextSecondary)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160, // max card width
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (_, i) {
                    final p      = _filteredProducts[i];
                    // Safe int conversion — API may return id as String or int
                    final pid = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
                    final isSelected = _selected.containsKey(pid);
                    final qty    = _selected[pid] ?? 0;

                    return _ProductCard(
                      productName:  p['productname'] ?? '',
                      price:        _safeDouble(p['saleprice']),
                      abbreviation: _getAbbreviation(p['productname'] ?? ''),
                      isSelected:   isSelected,
                      quantity:     qty,
                      qtyController: _qtyControllers[pid],
                      onTap:        () => _toggleProduct(pid),
                      onIncrease:   () => _changeQty(pid, 1),
                      onDecrease:   () => _changeQty(pid, -1),
                      onQtyChanged: (v) => _onQtyChanged(pid, v),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — order summary + confirmed items
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOrderPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Panel header ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          color: kPrimary,
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentOrderId == null
                      ? "Nouvelle commande"
                      : "Commande #$_currentOrderId",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              // Reset button
              if (_currentOrderId != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _currentOrderId = null;
                    _orderItems.clear();
                    _selected.clear();
                    for (final c in _qtyControllers.values) c.dispose();
                    _qtyControllers.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("Nouvelle",
                        style: TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),

        // ── Currently selected (not yet sent) ─────────────────────────
        if (_selected.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text("Sélection en cours",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
          ),
          ..._selected.entries.map((entry) {
            final product = _products.firstWhere(
                (p) => p['id'] == entry.key,
                orElse: () => <String, dynamic>{});
            if (product.isEmpty) return const SizedBox();
            final price    = _safeDouble(product['saleprice']);
            final subtotal = price * entry.value;
            return _OrderLineItem(
              name:     product['productname'] ?? '',
              qty:      entry.value,
              price:    price.toDouble(),
              subtotal: subtotal.toDouble(),
              onRemove: () => setState(() {
                _selected.remove(entry.key);
                _qtyControllers[entry.key]?.dispose();
                _qtyControllers.remove(entry.key);
              }),
            );
          }),
        ],

        // ── Confirmed order items (already sent to API) ───────────────
        if (_orderItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text("Articles confirmés",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSuccessColor)),
          ),
          ..._orderItems.map((item) => _OrderLineItem(
                name:     item['product_name'] ?? '',
                qty:      item['quantity'] ?? 0,
                price:    _safeDouble(item['price']),
                subtotal: _safeDouble(item['subtotal']),
                confirmed: true,
                onRemove: () => _cancelItem(
                    (item['order_item_id'] is int ? item['order_item_id'] as int : int.tryParse(item['order_item_id'].toString()) ?? 0),
                    item['product_name'] ?? ''),
              )),
        ],

        // ── Empty state ────────────────────────────────────────────────
        if (_selected.isEmpty && _orderItems.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      color: kTextSecondary.withOpacity(0.4), size: 44),
                  const SizedBox(height: 8),
                  const Text(
                    "Touchez une carte\npour sélectionner",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        const Spacer(),

        // ── Total + validate button ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardBg,
            border: const Border(top: BorderSide(color: kBorderColor)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -3)),
            ],
          ),
          child: Column(
            children: [
              // Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total estimé",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    "${_total.toStringAsFixed(0)} FCFA",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Validate button
              PrimaryButton(
                label: _currentOrderId == null
                    ? "Passer la commande"
                    : "Ajouter à #$_currentOrderId",
                onPressed: _validateOrder,
                isLoading: _placingOrder,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductCard — card showing one product in the grid
//
// Displays:
//   - Abbreviation (3 letters) in a colored circle
//   - Product name
//   - Sale price
//   - When selected: quantity controls (+/- and text input)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final String  productName;
  final double  price;
  final String  abbreviation;   // 3-letter abbreviation e.g. "POU"
  final bool    isSelected;
  final int     quantity;
  final TextEditingController? qtyController;
  final VoidCallback onTap;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<String> onQtyChanged;

  const _ProductCard({
    required this.productName,
    required this.price,
    required this.abbreviation,
    required this.isSelected,
    required this.quantity,
    required this.qtyController,
    required this.onTap,
    required this.onIncrease,
    required this.onDecrease,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          // Green when selected, white when not
          color: isSelected ? kPrimary : kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimary : kBorderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? kPrimary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Abbreviation circle + selection check ───────────────
            Row(
              children: [
                // Colored circle with abbreviation
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      abbreviation,
                      style: TextStyle(
                        color: isSelected ? Colors.white : kPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Checkmark icon when selected
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        size: 11, color: kPrimary),
                  ),
              ],
            ),
            const SizedBox(height: 7),

            // ── Product name ─────────────────────────────────────────
            Text(
              productName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : kTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // ── Sale price ───────────────────────────────────────────
            Text(
              "${price.toStringAsFixed(0)} F",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : kPrimary,
              ),
            ),

            // ── Quantity controls (only when selected) ───────────────
            if (isSelected) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  // Decrease button
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: onDecrease,
                  ),
                  const SizedBox(width: 4),

                  // Quantity text field — user can type directly
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: TextField(
                        controller: qtyController,
                        onChanged: onQtyChanged,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.number,
                        // Only allow digits — no letters or symbols
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Increase button
                  _QtyButton(
                    icon: Icons.add,
                    onTap: onIncrease,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small +/- button ──────────────────────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OrderLineItem — one line in the order summary panel
// ─────────────────────────────────────────────────────────────────────────────
class _OrderLineItem extends StatelessWidget {
  final String  name;
  final int     qty;
  final double  price;
  final double  subtotal;
  final bool    confirmed; // true = already sent to API
  final VoidCallback onRemove;

  const _OrderLineItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.subtotal,
    this.confirmed = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: confirmed
            ? kSuccessColor.withOpacity(0.06)
            : kBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: confirmed
              ? kSuccessColor.withOpacity(0.3)
              : kBorderColor,
        ),
      ),
      child: Row(
        children: [
          // Quantity badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: confirmed
                  ? kSuccessColor.withOpacity(0.15)
                  : kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                "$qty",
                style: TextStyle(
                    color: confirmed ? kSuccessColor : kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Product name + unit price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text("${price.toStringAsFixed(0)} F/u",
                    style: const TextStyle(
                        fontSize: 10, color: kTextSecondary)),
              ],
            ),
          ),

          // Subtotal
          Text(
            "${subtotal.toStringAsFixed(0)} F",
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kPrimary),
          ),
          const SizedBox(width: 4),

          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              confirmed ? Icons.cancel_outlined : Icons.close,
              size: 16,
              color: kErrorColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryChip — filter chip for category selection
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimary : kBorderColor,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: kPrimary.withOpacity(0.3), blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : kTextSecondary,
            fontSize: 12,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}