import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_crud_service.dart';
import 'crud_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CashierOrderScreen – classic vertical POS
// ─────────────────────────────────────────────────────────────────────────────

class CashierOrderScreen extends StatefulWidget {
  const CashierOrderScreen({super.key});

  @override
  State<CashierOrderScreen> createState() => _CashierOrderScreenState();
}

class _CashierOrderScreenState extends State<CashierOrderScreen> {
  final ProductCrudService _productService = ProductCrudService();
  final CrudService _crudService = CrudService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _cashController = TextEditingController();
  final FocusNode _cashFocus = FocusNode();

  static const Color primary = Color(0xFF8B1D1D);
  static const Color surface = Color(0xFFFAFAFA);

  // cart: productId → quantity
  final Map<String, int> _cart = {};
  bool _isProcessing = false;

  // ── computed ──────────────────────────────────────────────────────────────

  double _total(List<Product> products) {
    double t = 0;
    for (final e in _cart.entries) {
      final p = _productById(products, e.key);
      t += (p?.price ?? 0) * e.value;
    }
    return t;
  }

  Product? _productById(List<Product> products, String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  double get _cashPaid => double.tryParse(_cashController.text) ?? 0;

  // ── cart helpers ──────────────────────────────────────────────────────────

  void _add(String id) => setState(() => _cart[id] = (_cart[id] ?? 0) + 1);

  void _remove(String id) {
    setState(() {
      if ((_cart[id] ?? 0) <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = _cart[id]! - 1;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _cashController.clear();
    });
  }

  // ── order logic ───────────────────────────────────────────────────────────

  void _onConfirm(List<Product> products, List<Ingredient> inventory) {
    if (_cart.isEmpty) {
      _snack('Add at least one item first.', isError: true);
      return;
    }

    final total = _total(products);
    final cash = _cashPaid;

    if (cash <= 0) {
      _snack('Please enter the amount received from the customer.', isError: true);
      _cashFocus.requestFocus();
      return;
    }
    if (cash < total) {
      _snack('Cash received is less than the total amount.', isError: true);
      _cashFocus.requestFocus();
      return;
    }

    // compute ingredient deductions
    final Map<String, double> deductions = {};
    final Map<String, Ingredient> ingMap = {for (final i in inventory) i.id: i};

    for (final e in _cart.entries) {
      final p = _productById(products, e.key);
      if (p == null) continue;
      for (final req in p.ingredientsRequired) {
        final ingId = req['ingredient_id'] as String;
        final amount = (req['amount_needed'] as num).toDouble();
        deductions[ingId] = (deductions[ingId] ?? 0) + amount * e.value;
      }
    }

    // check stock
    final List<String> short = [];
    for (final e in deductions.entries) {
      final ing = ingMap[e.key];
      if (ing == null) continue;
      if (ing.currentStock < e.value) {
        short.add('${ing.name}: need ${e.value}${ing.unit}, have ${ing.currentStock}${ing.unit}');
      }
    }
    if (short.isNotEmpty) {
      _showStockError(short);
      return;
    }

    _showReceipt(products, total, cash, deductions, ingMap);
  }

  Future<void> _commitOrder(
      Map<String, double> deductions, Map<String, Ingredient> ingMap, List<Product> products, double total) async {
    setState(() => _isProcessing = true);
    try {
      final batch = _firestore.batch();
      for (final e in deductions.entries) {
        final ing = ingMap[e.key];
        if (ing == null) continue;
        batch.update(_firestore.collection('inventory').doc(e.key), {
          'current_stock': (ing.currentStock - e.value).clamp(0, double.infinity),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Record the order for analytics
      final orderRef = _firestore.collection('orders').doc();
      final items = _cart.entries.map((e) {
        final p = _productById(products, e.key);
        return {
          'product_id': e.key,
          'product_name': p?.name ?? 'Unknown',
          'quantity': e.value,
          'price': p?.price ?? 0.0,
        };
      }).toList();

      batch.set(orderRef, {
        'total_amount': total,
        'items': items,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _clearCart();
      _snack('Order completed!');
    } catch (err) {
      _snack('Error: $err', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── dialogs ───────────────────────────────────────────────────────────────

  void _showStockError(List<String> items) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Insufficient Stock',
              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $s', style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReceipt(
    List<Product> products,
    double total,
    double cash,
    Map<String, double> deductions,
    Map<String, Ingredient> ingMap,
  ) {
    final change = cash - total;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Order Summary',
            style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- items ---
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, color: primary)),
              const Divider(),
              ..._cart.entries.map((e) {
                final p = _productById(products, e.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${p?.name ?? '?'} × ${e.value}',
                          style: const TextStyle(fontSize: 14))),
                      Text('₱${((p?.price ?? 0) * e.value).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: primary)),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              // --- totals ---
              _receiptRow('Total', '₱${total.toStringAsFixed(2)}', bold: true),
              const SizedBox(height: 4),
              _receiptRow('Cash', '₱${cash.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    Text('₱${change.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                  ],
                ),
              ),
              if (deductions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Inventory deductions',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 4),
                ...deductions.entries.map((e) {
                  final ing = ingMap[e.key];
                  if (ing == null) return const SizedBox.shrink();
                  return Text('- ${ing.name}: ${e.value} ${ing.unit}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54));
                }),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _commitOrder(deductions, ingMap, products, total);
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirm & Complete'),
            style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: bold ? primary : Colors.black87)),
        ],
      );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _cashController.dispose();
    _cashFocus.dispose();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ingredient>>(
      stream: _crudService.getInventoryStream(),
      builder: (context, invSnap) {
        final inventory = invSnap.data ?? [];
        return StreamBuilder<List<Product>>(
          stream: _productService.getProductsStream(),
          builder: (context, prodSnap) {
            if (prodSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primary));
            }
            final products = prodSnap.data ?? [];
            final total = _total(products);

            return Column(
              children: [
                // ══════════════════════════════════════════════════════════
                // SECTION 1 — Menu buttons (tappable grid)
                // ══════════════════════════════════════════════════════════
                Container(
                  color: surface,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MENU',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: primary)),
                      const SizedBox(height: 8),
                      products.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: Text('No products found.',
                                      style: TextStyle(color: Colors.black38))),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: products.map((p) {
                                // stock check
                                bool inStock = true;
                                for (final req in p.ingredientsRequired) {
                                  final ingId = req['ingredient_id'] as String;
                                  final needed = (req['amount_needed'] as num).toDouble();
                                  final ing = inventory.firstWhere(
                                    (i) => i.id == ingId,
                                    orElse: () => Ingredient(
                                        id: '',
                                        name: '',
                                        currentStock: 0,
                                        unit: '',
                                        lowStockThreshold: 0),
                                  );
                                  if (ing.currentStock < needed) {
                                    inStock = false;
                                    break;
                                  }
                                }
                                return _MenuButton(
                                  product: p,
                                  inStock: inStock,
                                  onTap: inStock ? () => _add(p.id) : null,
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

                // ══════════════════════════════════════════════════════════
                // SECTION 2 — Order list
                // ══════════════════════════════════════════════════════════
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 56, color: primary.withValues(alpha: 0.18)),
                              const SizedBox(height: 8),
                              Text('Tap a menu item to add it',
                                  style: TextStyle(color: primary.withValues(alpha: 0.4), fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            // header row
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Row(
                                children: const [
                                  Expanded(flex: 4,
                                      child: Text('ITEM',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: Colors.black38))),
                                  SizedBox(width: 8),
                                  Text('QTY',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          color: Colors.black38)),
                                  SizedBox(width: 8),
                                  SizedBox(
                                      width: 72,
                                      child: Text('SUBTOTAL',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: Colors.black38))),
                                  SizedBox(width: 40),
                                ],
                              ),
                            ),
                            ..._cart.entries.map((e) {
                              final p = _productById(products, e.key);
                              if (p == null) return const SizedBox.shrink();
                              final sub = p.price * e.value;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFEEEEEE)),
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      // name
                                      Expanded(
                                        flex: 4,
                                        child: Text(p.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87)),
                                      ),
                                      // qty stepper
                                      _Stepper(
                                        qty: e.value,
                                        onAdd: () => _add(e.key),
                                        onRemove: () => _remove(e.key),
                                      ),
                                      // subtotal
                                      SizedBox(
                                        width: 72,
                                        child: Text('₱${sub.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: primary)),
                                      ),
                                      // delete
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _cart.remove(e.key)),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.close,
                                              size: 16, color: Colors.black38),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                ),

                // ══════════════════════════════════════════════════════════
                // SECTION 3 — Cash panel
                // ══════════════════════════════════════════════════════════
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 10,
                          offset: Offset(0, -3))
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      // total row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: Colors.black54)),
                          Text('₱${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primary)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // cash input
                      Row(
                        children: [
                          const Text('Cash Received',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                          const Spacer(),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _cashController,
                              focusNode: _cashFocus,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                              ],
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              decoration: InputDecoration(
                                prefixText: '₱ ',
                                prefixStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54),
                                hintText: '0.00',
                                hintStyle:
                                    const TextStyle(color: Colors.black26, fontSize: 18),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: primary, width: 1.5)),
                              ),
                              onChanged: (_) {},
                            ),
                          ),
                        ],
                      ),

                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _cashController,
                        builder: (context, value, _) {
                          final cash = double.tryParse(value.text) ?? 0;
                          final change = cash - total;
                          final hasEnough = cash >= total && total > 0;
                          if (cash <= 0 || total <= 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  hasEnough ? 'Change' : 'Still needed',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: hasEnough ? Colors.green[700] : Colors.red[700]),
                                ),
                                Text(
                                  hasEnough
                                      ? '₱${change.toStringAsFixed(2)}'
                                      : '₱${(total - cash).toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: hasEnough ? Colors.green[700] : Colors.red[700]),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // action row
                      Row(
                        children: [
                          // Clear
                          OutlinedButton.icon(
                            onPressed: _cart.isEmpty ? null : _clearCart,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: const BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Confirm
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : () => _onConfirm(products, inventory),
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Confirm Order',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu button widget
// ─────────────────────────────────────────────────────────────────────────────

class _MenuButton extends StatelessWidget {
  final Product product;
  final bool inStock;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.product,
    required this.inStock,
    required this.onTap,
  });

  static const Color primary = Color(0xFF8B1D1D);

  static const Map<String, String> _flavorAssets = {
    'bbq': 'assets/bbq.jpg',
    'curry': 'assets/curry.jpg',
    'gravy': 'assets/gravy.jpg',
    'teriyaki': 'assets/teriyaki.jpg',
  };

  String? _getFlavorAsset() {
    final key = product.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _flavorAssets[key];
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _getFlavorAsset();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: inStock ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          boxShadow: inStock
              ? [
                  BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: inStock ? 1 : 0.45,
              child: assetPath != null
                  ? Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.asset(assetPath, fit: BoxFit.cover),
                        ),
                      ),
                    )
                  : Icon(Icons.rice_bowl,
                      size: 26,
                      color: inStock ? Colors.white : Colors.grey.shade400),
            ),
            const SizedBox(height: 4),
            Text(
              product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: inStock ? Colors.white : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '₱${product.price.toStringAsFixed(0)}',
              style: TextStyle(
                  color: inStock ? Colors.white70 : Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
            if (!inStock)
              const Text('OUT',
                  style: TextStyle(
                      color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Qty stepper row inside order list
// ─────────────────────────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _Stepper({required this.qty, required this.onAdd, required this.onRemove});

  static const Color primary = Color(0xFF8B1D1D);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(icon: Icons.remove, onTap: onRemove),
        SizedBox(
          width: 28,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: primary)),
        ),
        _Btn(icon: Icons.add, onTap: onAdd),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFF8B1D1D).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF8B1D1D)),
      ),
    );
  }
}
