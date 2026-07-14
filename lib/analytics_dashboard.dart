import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'analytics_service.dart';
import 'todays_sales_card.dart';

const Color _primary = Color(0xFF8B1D1D);
const Color _primaryLight = Color(0xFFBF3131);
const Color _surface = Color(0xFFFAFAFA);
const Color _cardBg = Colors.white;

final List<Color> _pieColors = [
  const Color(0xFF8B1D1D),
  const Color(0xFFBF3131),
  const Color(0xFFE05A5A),
  const Color(0xFFF5A623),
  const Color(0xFF4A90D9),
  const Color(0xFF7ED321),
  const Color(0xFF9B59B6),
  const Color(0xFF2ECC71),
];

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  int _selectedDays = 7;
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsService>().loadAnalytics(days: _selectedDays);
    });
  }

  void _reload(int days) {
    setState(() {
      _selectedDays = days;
      _touchedPieIndex = -1;
    });
    context.read<AnalyticsService>().loadAnalytics(days: days);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select period',
            onSelected: _reload,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
          ),
        ],
      ),
      body: Consumer<AnalyticsService>(
        builder: (context, svc, _) {
          if (svc.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (svc.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: _primary, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      svc.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _reload(_selectedDays),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final analyticsData = svc.data;

          if (analyticsData == null ||
              (analyticsData.revenuePoints.isEmpty &&
                  analyticsData.productStats.isEmpty)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_outlined,
                      size: 64, color: _primary.withValues(alpha: 0.25)),
                  const SizedBox(height: 16),
                  const Text(
                    'No sales data found for this period.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orders will appear here once sales are recorded.',
                    style: TextStyle(fontSize: 13, color: Colors.black38),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: _primary,
            onRefresh: () => svc.loadAnalytics(days: _selectedDays),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Real-time Today's Sales KPI ──────────────────────
                const TodaysSalesCard(),
                const SizedBox(height: 16),
                _PeriodHeader(days: _selectedDays),
                const SizedBox(height: 12),
                _BestSellerCard(bestSeller: analyticsData.bestSeller),
                const SizedBox(height: 16),
                _RevenueSummaryRow(points: analyticsData.revenuePoints),
                const SizedBox(height: 16),
                _SectionHeader(title: 'Revenue Trend', subtitle: 'Last $_selectedDays days'),
                const SizedBox(height: 8),
                _RevenueLineChart(points: analyticsData.revenuePoints),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Flavor Breakdown',
                  subtitle: 'Units sold per product',
                ),
                const SizedBox(height: 8),
                _ProductPieChart(
                  stats: analyticsData.productStats,
                  touchedIndex: _touchedPieIndex,
                  onTouch: (i) => setState(() => _touchedPieIndex = i),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Product Rankings',
                  subtitle: 'Sorted by units sold',
                ),
                const SizedBox(height: 8),
                _ProductBarChart(stats: analyticsData.productStats),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  final int days;
  const _PeriodHeader({required this.days});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Last $days days',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  final BestSeller? bestSeller;
  const _BestSellerCard({required this.bestSeller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: bestSeller == null
          ? const Row(
              children: [
                Icon(Icons.star_border, color: Colors.white70, size: 32),
                SizedBox(width: 12),
                Text(
                  'No best seller yet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'BEST SELLER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  bestSeller!.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${bestSeller!.totalSold} units sold',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _RevenueSummaryRow extends StatelessWidget {
  final List<RevenuePoint> points;
  const _RevenueSummaryRow({required this.points});

  @override
  Widget build(BuildContext context) {
    final totalRevenue = points.fold<double>(0, (s, p) => s + p.total);
    final avgRevenue = points.isEmpty ? 0.0 : totalRevenue / points.length;
    final peakRevenue = points.isEmpty
        ? 0.0
        : points.map((p) => p.total).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Total Revenue',
            value: 'P${totalRevenue.toStringAsFixed(2)}',
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Daily Avg',
            value: 'P${avgRevenue.toStringAsFixed(2)}',
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Peak Day',
            value: 'P${peakRevenue.toStringAsFixed(2)}',
            icon: Icons.emoji_events_outlined,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

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

class _RevenueLineChart extends StatelessWidget {
  final List<RevenuePoint> points;

  const _RevenueLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxY = points.isEmpty
        ? 100.0
        : points.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    final chartMax = (maxY * 1.25).ceilToDouble();
    final interval = chartMax == 0 ? 50.0 : (chartMax / 4).ceilToDouble();

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.total))
        .toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: points.every((p) => p.total == 0)
          ? const Center(
              child: Text(
                'No revenue recorded in this period.',
                style: TextStyle(color: Colors.black38, fontSize: 13),
              ),
            )
          : LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: chartMax,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max) return const SizedBox.shrink();
                        return Text(
                          'P${value.toInt()}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black38,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final dt = points[idx].date;
                        final label =
                            '${dt.month}/${dt.day}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black38,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => _primary.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        String dateStr = '';
                        if (idx >= 0 && idx < points.length) {
                          final dt = points[idx].date;
                          dateStr = '${dt.month}/${dt.day}\n';
                        }
                        return LineTooltipItem(
                          '$dateStr P${spot.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: _primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _primary.withValues(alpha: 0.22),
                          _primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductPieChart extends StatelessWidget {
  final List<ProductStat> stats;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _ProductPieChart({
    required this.stats,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: const Text(
          'No product data.',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    final totalQty = stats.fold<int>(0, (s, p) => s + p.quantity);
    final displayStats = stats.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            onTouch(-1);
                            return;
                          }
                          onTouch(
                            response.touchedSection!.touchedSectionIndex,
                          );
                        },
                      ),
                      sections: displayStats.asMap().entries.map((e) {
                        final isTouched = e.key == touchedIndex;
                        final pct = totalQty == 0
                            ? 0.0
                            : e.value.quantity / totalQty * 100;
                        return PieChartSectionData(
                          color: _pieColors[e.key % _pieColors.length],
                          value: e.value.quantity.toDouble(),
                          title: isTouched
                              ? '${pct.toStringAsFixed(1)}%'
                              : '',
                          radius: isTouched ? 70 : 58,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: displayStats.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _pieColors[e.key % _pieColors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              e.value.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${e.value.quantity})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBarChart extends StatelessWidget {
  final List<ProductStat> stats;

  const _ProductBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: const Text(
          'No product data.',
          style: TextStyle(color: Colors.black38),
        ),
      );
    }

    final displayStats = stats.take(6).toList();
    final maxQty = displayStats
        .map((p) => p.quantity)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final chartMax = (maxQty * 1.2).ceilToDouble();
    final interval = chartMax == 0 ? 5.0 : (chartMax / 4).ceilToDouble();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _primary.withValues(alpha: 0.9),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final name = displayStats[groupIndex].name;
                return BarTooltipItem(
                  '$name\n${rod.toY.toInt()} units',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= displayStats.length) {
                    return const SizedBox.shrink();
                  }
                  final name = displayStats[idx].name;
                  final label = name.length > 8 ? '${name.substring(0, 7)}.' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.black38,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.black.withValues(alpha: 0.06),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: displayStats.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.quantity.toDouble(),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      _pieColors[e.key % _pieColors.length].withValues(alpha: 0.7),
                      _pieColors[e.key % _pieColors.length],
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
