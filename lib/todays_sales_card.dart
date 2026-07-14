import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'analytics_service.dart';
import 'todays_sales_detail_page.dart';

// ---------------------------------------------------------------------------
// Design tokens – kept consistent with analytics_dashboard.dart
// ---------------------------------------------------------------------------
const Color _primary = Color(0xFF8B1D1D);
const Color _primaryLight = Color(0xFFBF3131);
const Color _cardBg = Colors.white;

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// A standalone dashboard card that shows the running total of all sales
/// placed today (local calendar day, 00:00:00 → now) in real-time.
///
/// Tapping the card navigates to [TodaysSalesDetailPage] for a full
/// itemised breakdown of today's orders.
///
/// Requires [AnalyticsService] to be provided in the widget tree via [Provider].
class TodaysSalesCard extends StatefulWidget {
  const TodaysSalesCard({super.key});

  @override
  State<TodaysSalesCard> createState() => _TodaysSalesCardState();
}

class _TodaysSalesCardState extends State<TodaysSalesCard> {
  // ── The stream is created once and held here so it survives rebuilds ──────
  late Stream<double> _salesStream;
  bool _streamInitialized = false;

  @override
  void initState() {
    super.initState();
    // Pull the stream from the service once the context is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _salesStream =
            context.read<AnalyticsService>().getTodaysSalesStream();
        _streamInitialized = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show shimmer until the post-frame callback fires.
    if (!_streamInitialized) return _ShimmerCard();

    return StreamBuilder<double>(
      stream: _salesStream,
      builder: (context, snapshot) {
        // ── Loading (waiting for first Firestore event) ───────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _ShimmerCard();
        }

        // ── Error ─────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return _buildCard(
            context: context,
            amountText: '₱0.00',
            isError: true,
            errorMessage: 'Could not load sales data.',
          );
        }

        // ── Data (including 0.0 when no orders exist yet today) ───────────
        final total = snapshot.data ?? 0.0;
        return _buildCard(
          context: context,
          amountText: _formatCurrency(total),
        );
      },
    );
  }

  // ── Card layout ──────────────────────────────────────────────────────────

  Widget _buildCard({
    required BuildContext context,
    required String amountText,
    bool isError = false,
    String? errorMessage,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isError
            ? null // Disable tap in error state
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TodaysSalesDetailPage(),
                  ),
                );
              },
        child: Ink(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withValues(alpha: 0.25)
                  : const Color(0xFFEEEEEE),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gradient accent bar ────────────────────────────────
                Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _primaryLight],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: icon + title + chevron ─────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon circle
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.point_of_sale_rounded,
                              color: _primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Sales Today',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          // Error badge or tap-to-view chevron
                          if (isError)
                            const _ErrorBadge()
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _primary.withValues(alpha: 0.45),
                              size: 22,
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Large amount ───────────────────────────────
                      Text(
                        amountText,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color:
                              isError ? Colors.redAccent.shade400 : _primary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ── Sub-label ──────────────────────────────────
                      Text(
                        isError
                            ? (errorMessage ?? 'Unable to retrieve sales.')
                            : 'Total Sales Today',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isError ? Colors.redAccent : Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Divider ────────────────────────────────────
                      Divider(
                        color: Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),

                      const SizedBox(height: 14),

                      // ── Footer: calendar date ──────────────────────
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _todayLabel(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (!isError)
                            Text(
                              'Tap for breakdown',
                              style: TextStyle(
                                fontSize: 10,
                                color: _primary.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Formats [amount] as Philippine Peso, e.g. ₱1,250.00
  String _formatCurrency(double amount) {
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

  /// Returns a human-readable label for today, e.g. "Mon, Jul 14 2026"
  String _todayLabel() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day} ${now.year}';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

/// Static red badge shown when a stream error occurs.
class _ErrorBadge extends StatelessWidget {
  const _ErrorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 10, color: Colors.redAccent),
          SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pure-Flutter shimmer skeleton shown while waiting for the first snapshot.
/// No external packages required – uses a looping LinearGradient animation.
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top accent bar (static)
              Container(
                height: 5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, _primaryLight],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _box(width: 40, height: 40, radius: 20),
                        const SizedBox(width: 12),
                        _box(width: 100, height: 14, radius: 7),
                        const Spacer(),
                        _box(width: 22, height: 22, radius: 11),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _box(width: 180, height: 38, radius: 8),
                    const SizedBox(height: 10),
                    _box(width: 120, height: 12, radius: 6),
                    const SizedBox(height: 20),
                    Divider(color: Colors.black.withValues(alpha: 0.06)),
                    const SizedBox(height: 14),
                    _box(width: 140, height: 11, radius: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({
    required double width,
    required double height,
    required double radius,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(_anim.value - 1, 0),
        end: Alignment(_anim.value, 0),
        colors: const [
          Color(0xFFE8E8E8),
          Color(0xFFF5F5F5),
          Color(0xFFE8E8E8),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
