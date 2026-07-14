import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RevenuePoint {
  final DateTime date;
  final double total;

  RevenuePoint({required this.date, required this.total});
}

class ProductStat {
  final String name;
  final int quantity;

  ProductStat({required this.name, required this.quantity});
}

class BestSeller {
  final String name;
  final int totalSold;

  BestSeller({required this.name, required this.totalSold});
}

class AnalyticsData {
  final List<RevenuePoint> revenuePoints;
  final List<ProductStat> productStats;
  final BestSeller? bestSeller;

  AnalyticsData({
    required this.revenuePoints,
    required this.productStats,
    required this.bestSeller,
  });
}

class AnalyticsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnalyticsData? _data;
  bool _isLoading = false;
  String? _error;

  AnalyticsData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAnalytics({int days = 7}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cutoff = DateTime.now().subtract(Duration(days: days - 1));
      final cutoffDate = DateTime(cutoff.year, cutoff.month, cutoff.day);
      final cutoffTs = Timestamp.fromDate(cutoffDate);

      final snapshot = await _firestore
          .collection('orders')
          .where('timestamp', isGreaterThanOrEqualTo: cutoffTs)
          .orderBy('timestamp')
          .get();

      final Map<String, double> revenueByDate = {};
      final Map<String, int> productTotals = {};

      for (int i = 0; i < days; i++) {
        final d = cutoffDate.add(Duration(days: i));
        final key = _dateKey(d);
        revenueByDate[key] = 0;
      }

      for (final doc in snapshot.docs) {
        final rawTs = doc.data()['timestamp'];
        final double amount =
            (doc.data()['total_amount'] as num?)?.toDouble() ?? 0.0;

        if (rawTs is Timestamp) {
          final dt = rawTs.toDate();
          final key = _dateKey(dt);
          revenueByDate[key] = (revenueByDate[key] ?? 0) + amount;
        }

        final rawItems = doc.data()['items'];
        if (rawItems is List) {
          for (final raw in rawItems) {
            if (raw is Map) {
              final name = (raw['product_name'] as String?) ?? 'Unknown';
              final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
              productTotals[name] = (productTotals[name] ?? 0) + qty;
            }
          }
        }
      }

      final revenuePoints = revenueByDate.entries.map((e) {
        final parts = e.key.split('-');
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return RevenuePoint(date: dt, total: e.value);
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final productStats = productTotals.entries
          .map((e) => ProductStat(name: e.key, quantity: e.value))
          .toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));

      BestSeller? bestSeller;
      if (productStats.isNotEmpty) {
        bestSeller = BestSeller(
          name: productStats.first.name,
          totalSold: productStats.first.quantity,
        );
      }

      _data = AnalyticsData(
        revenuePoints: revenuePoints,
        productStats: productStats,
        bestSeller: bestSeller,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Returns a real-time [Stream<double>] of total sales for the current
  /// calendar day (midnight 00:00:00 local time → now).
  ///
  /// The boundary is re-evaluated each time the stream is subscribed, so it
  /// correctly reflects "today" even if the app has been running across
  /// midnight. Re-subscribe (e.g. by recreating the widget) after midnight
  /// if persistent accuracy across midnight is required.
  Stream<double> getTodaysSalesStream() {
    // Compute midnight of today in the device's local timezone.
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day); // 00:00:00 local
    final startTimestamp = Timestamp.fromDate(startOfToday);

    return _firestore
        .collection('orders')
        .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
        .snapshots()
        .map((snapshot) {
      double total = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;
      }
      return total;
    });
  }

  /// Canonical alias for [getTodaysSalesStream].
  ///
  /// Streams the real-time gross revenue total for the current calendar day
  /// (00:00:00 local time → now). Returns `0.0` safely when no orders exist.
  /// The midnight boundary is evaluated at subscription time and correctly
  /// uses the device's local timezone — not UTC — preventing miscalculations
  /// at day boundaries.
  Stream<double> streamTodaysSales() => getTodaysSalesStream();
}
