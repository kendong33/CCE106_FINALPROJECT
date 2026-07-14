import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'analytics_service.dart';

// ---------------------------------------------------------------------------
// Design tokens – kept consistent with the rest of the app
// ---------------------------------------------------------------------------
const Color _primary = Color(0xFF8B1D1D);
const Color _primaryLight = Color(0xFFBF3131);
const Color _surface = Color(0xFFFAFAFA);
const Color _cardBg = Colors.white;

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// Aggregated sales data for a single product type across all orders today.
class _ProductAggregate {
  final String name;
  int totalQty;
  double totalRevenue;

  _ProductAggregate({
    required this.name,
    required this.totalQty,
    required this.totalRevenue,
  });
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// Full-screen breakdown of all products sold during the current calendar day.
///
/// Queries the same `orders` collection used by [AnalyticsService], groups
/// all order line-items by `product_name`, sums quantities and revenue,
/// and renders a sorted [ListView] with a running-total summary banner.
class TodaysSalesDetailPage extends StatefulWidget {
  const TodaysSalesDetailPage({super.key});

  @override
  State<TodaysSalesDetailPage> createState() => _TodaysSalesDetailPageState();
}

class _TodaysSalesDetailPageState extends State<TodaysSalesDetailPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();

    // Compute midnight of today in the device''s local timezone.
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startTimestamp = Timestamp.fromDate(startOfToday);

    // Subscribe to the raw order documents so we can access the items list.
    // We reuse the same Firestore instance from AnalyticsService (via Provider)
    // rather than creating a second FirebaseFirestore.instance.
    final firestore = FirebaseFirestore.instance;
    _ordersStream = firestore
        .collection('orders')
        .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
        .snapshots();
  }

  // ── Aggregation ──────────────────────────────────────────────────────────

  /// Reads raw Firestore order documents and produces a sorted list of
  /// [_ProductAggregate] objects grouped by product name.
  ///
  /// For each order document:
  ///  1. The `items` field is read as a [List] of [Map]s.
  ///  2. Each item''s `product_name`, `quantity`, and `price` are extracted.
  ///  3. Items with the same name are merged – quantities are added, and
  ///     revenue is accumulated as `quantity × price`.
  ///
  /// The result is sorted descending by total revenue.
  List<_ProductAggregate> _aggregate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // productName → aggregate
    final Map<String, _ProductAggregate> map = {};

    for (final doc in docs) {
      final data = doc.data();
      final rawItems = data['items'];

      if (rawItems is! List) continue;

      for (final raw in rawItems) {
        if (raw is! Map) continue;

        final name =
            (raw['product_name'] as String?)?.trim() ?? 'Unknown Product';
        final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
        final price = (raw['price'] as num?)?.toDouble() ?? 0.0;
        final lineRevenue = qty * price;

        if (map.containsKey(name)) {
          map[name]!.totalQty += qty;
          map[name]!.totalRevenue += lineRevenue;
        } else {
          map[name] = _ProductAggregate(
            name: name,
            totalQty: qty,
            totalRevenue: lineRevenue,
          );
        }
      }
    }

    // Sort by revenue descending so best performers appear first.
    final list = map.values.toList();
    list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return list;
  }

  // ── Currency helper ──────────────────────────────────────────────────────

  String _fmt(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    final chars = intPart.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(chars[i]);
    }
    final formatted = buffer.toString().split('').reversed.join();
    return '₱$formatted.$decPart';
  }

  // ── Today label ──────────────────────────────────────────────────────────

  String _todayLabel() {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Today''s Sales Breakdown",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          // ── Loading ────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          // ── Error ──────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: _primary.withValues(alpha: 0.6), size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load sales data.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final products = _aggregate(docs);

          // Total gross revenue across all products today
          final grandTotal =
              products.fold<double>(0, (acc, p) => acc + p.totalRevenue);

          // Total units sold today
          final totalUnits =
              products.fold<int>(0, (acc, p) => acc + p.totalQty);

          // ── Empty state ────────────────────────────────────────────────
          if (products.isEmpty) {
            return _buildEmptyState();
          }

          // ── Data ───────────────────────────────────────────────────────
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Date label ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _todayLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Summary banner ──────────────────────────────────────────
              _SummaryBanner(
                totalRevenue: grandTotal,
                totalUnits: totalUnits,
                productCount: products.length,
                formatFn: _fmt,
              ),

              const SizedBox(height: 20),

              // ── Section header ──────────────────────────────────────────
              _SectionHeader(
                title: 'Product Breakdown',
                subtitle: '${products.length} product${products.length == 1 ? '' : 's'} sold today',
              ),

              const SizedBox(height: 10),

              // ── Product rows ────────────────────────────────────────────
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProductRow(
                    rank: index + 1,
                    product: product,
                    grandTotal: grandTotal,
                    formatFn: _fmt,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 46,
                color: _primary.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No products sold yet today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sales will appear here as orders are placed throughout the day.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black38,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Prominent banner showing today''s total revenue, units sold, and
/// number of distinct products.
class _SummaryBanner extends StatelessWidget {
  final double totalRevenue;
  final int totalUnits;
  final int productCount;
  final String Function(double) formatFn;

  const _SummaryBanner({
    required this.totalRevenue,
    required this.totalUnits,
    required this.productCount,
    required this.formatFn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              const Icon(
                Icons.attach_money_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'TOTAL REVENUE TODAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Big number
          Text(
            formatFn(totalRevenue),
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _StatPill(
                icon: Icons.shopping_bag_outlined,
                label: '$totalUnits unit${totalUnits == 1 ? '' : 's'} sold',
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.category_outlined,
                label: '$productCount product${productCount == 1 ? '' : 's'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small translucent pill used inside [_SummaryBanner].
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with coloured left accent bar.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single product row card showing rank, name, quantity, and revenue.
class _ProductRow extends StatelessWidget {
  final int rank;
  final _ProductAggregate product;
  final double grandTotal;
  final String Function(double) formatFn;

  const _ProductRow({
    required this.rank,
    required this.product,
    required this.grandTotal,
    required this.formatFn,
  });

  @override
  Widget build(BuildContext context) {
    // Revenue share percentage for the progress bar
    final share = grandTotal > 0 ? product.totalRevenue / grandTotal : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Rank badge ─────────────────────────────────────────
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFF5A623).withValues(alpha: 0.15)
                        : _primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: rank == 1
                          ? const Color(0xFFD4820A)
                          : _primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Name ───────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Qty sold: ${product.totalQty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Revenue ────────────────────────────────────────────
                Text(
                  formatFn(product.totalRevenue),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),

          // ── Revenue share bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 4,
                    backgroundColor:
                        _primary.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(share * 100).toStringAsFixed(1)}% of today''s revenue',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
