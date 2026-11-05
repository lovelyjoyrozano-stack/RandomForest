import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import 'dart:math' as math;

// GREEN THEME
const Color forestGreen = Color(0xFF07502D);
const Color darkGreen = Color(0xFF064326);
const Color primaryGreen = Color(0xFF16813A);
const Color lightGreen = Color(0xFFEAF5E8);
const Color pageBackground = Color(0xFFF7FAF7);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 82,
          elevation: 0,
          foregroundColor: Colors.white,
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF278B43),
                  Color(0xFF07552E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_queue_rounded, size: 37),
              SizedBox(width: 18),
              SizedBox(
                height: 42,
                child: VerticalDivider(
                  color: Colors.white54,
                  thickness: 2,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Weather & Productivity Record History',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: Container(
              color: const Color(0xFFF0F6F0),
              padding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: primaryGreen, width: 1.5),
                    left: BorderSide(color: primaryGreen, width: 1.5),
                    right: BorderSide(color: primaryGreen, width: 1.5),
                    bottom: BorderSide(color: primaryGreen, width: 4),
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                dividerColor: const Color(0xFFDCE8DD),
                labelColor: forestGreen,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                tabs: const [
                  Tab(
                    height: 65,
                    icon: Icon(Icons.agriculture_rounded, size: 27),
                    text: 'Weather History',
                  ),
                  Tab(
                    height: 65,
                    icon: Icon(Icons.insert_chart_rounded, size: 27),
                    text: 'Productivity History',
                  ),
                ],
              ),
            ),
          ),
        ),
       body: Stack(
  children: [
    // BACKGROUND IMAGE
    Positioned.fill(
  child: Image.asset(
     'assets/images/weather&crop_productivity_record_history.png',
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      color: pageBackground,
    ),
  ),
),


    

    // ORIGINAL CONTENT
    ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final farm = store.selected;

        if (farm == null) {
          return const Center(
            child: Text('Register a farm first.'),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: FarmSelectorBar(store: store),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                key: ValueKey(farm.id),
                children: [
                  _WeatherHistoryTab(
                    farmId: farm.id,
                    location: farm.city?.isNotEmpty == true
                        ? farm.city!
                        : farm.location,
                  ),
                  _ProductivityHistoryTab(
                    farmId: farm.id,
                  ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


// ==========================================
// WEATHER HISTORY
// ==========================================

class _WeatherHistoryTab extends StatefulWidget {
  final int farmId;
  final String location;

  const _WeatherHistoryTab({
    required this.farmId,
    required this.location,
  });

  @override
  State<_WeatherHistoryTab> createState() =>
      _WeatherHistoryTabState();
}

class _WeatherHistoryTabState extends State<_WeatherHistoryTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiClient.instance.get(
        '/climate/history',
        query: {
          'farm_id': widget.farmId,
          'limit': 365,
        },
      );

      final list = (result as Map)['readings'] as List? ?? [];

      if (mounted) {
        setState(() {
          _records = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryGreen,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: primaryGreen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (_error != null)
            ErrorBanner(_error!, onRetry: _load),

          if (_records.isEmpty && _error == null)
            const _EmptyHistory(
              icon: Icons.cloud_off_rounded,
              message: 'No weather records found',
            ),

          for (final r in _records)
            _WeatherRecordCard(
              record: r,
              location: widget.location,
            ),
        ],
      ),
    );
  }
}

class _WeatherRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final String location;

  const _WeatherRecordCard({
    required this.record,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF0F8EF),
            Color(0xFFE5F2E3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD5E8D4),
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final metrics = Column(
            children: [
              _WeatherMetric(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: '${record['temperature'] ?? '—'} °C',
              ),
              _WeatherMetric(
                icon: Icons.water_drop_rounded,
                label: 'Humidity',
                value: '${record['humidity'] ?? '—'} %',
              ),
              _WeatherMetric(
                icon: Icons.cloudy_snowing,
                label: 'Rainfall',
                value: '${record['rainfall'] ?? '—'} mm',
              ),
              _WeatherMetric(
                icon: Icons.cloud_queue_rounded,
                label: 'Condition',
                value: '${record['weather_condition'] ?? 'Unknown'}',
              ),
              _WeatherMetric(
                icon: Icons.umbrella_rounded,
                label: 'Rain probability',
                value: '${record['rain_probability'] ?? '—'} %',
              ),
              _WeatherMetric(
                icon: Icons.calendar_month_rounded,
                label: 'Date recorded',
                value: _date(record['created_at']),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: primaryGreen,
                    size: 29,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: darkGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!compact)
                    const Icon(
                      Icons.wb_cloudy_rounded,
                      color: Color(0xFF9ACB88),
                      size: 55,
                    ),
                ],
              ),
              const SizedBox(height: 17),
              if (compact)
                metrics
              else
                Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: metrics,
                    ),
                    Container(
                      width: 1,
                      height: 230,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 25,
                      ),
                      color: const Color(0xFFB8D9BC),
                    ),
                    const Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Icon(
                                Icons.landscape_rounded,
                                color: Color(0xFFB4D8A8),
                                size: 130,
                              ),
                            ),
                            Icon(
                              Icons.wb_cloudy_rounded,
                              color: Colors.white,
                              size: 100,
                            ),
                            Positioned(
                              top: 12,
                              right: 20,
                              child: Icon(
                                Icons.wb_sunny_rounded,
                                color: Color(0xFFFFC928),
                                size: 55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryGreen,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF405C4C),
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF17251E),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PRODUCTIVITY HISTORY
// ==========================================

class _ProductivityHistoryTab extends StatefulWidget {
  final int farmId;

  const _ProductivityHistoryTab({
    required this.farmId,
  });

  @override
  State<_ProductivityHistoryTab> createState() =>
      _ProductivityHistoryTabState();
}

class _ProductivityHistoryTabState
    extends State<_ProductivityHistoryTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiClient.instance.get(
        '/productivity/records',
        query: {
          'farm_id': widget.farmId,
          'limit': 500,
        },
      );

      final list = (result as Map)['records'] as List? ?? [];

      if (mounted) {
        setState(() {
          _records = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryGreen,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: primaryGreen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (_error != null)
            ErrorBanner(_error!, onRetry: _load),

          if (_records.isEmpty && _error == null)
            const _EmptyHistory(
              icon: Icons.grass_rounded,
              message: 'No productivity records found',
            ),

          for (final r in _records)
            _ProductivityRecordCard(record: r),
        ],
      ),
    );
  }
}

// ==========================================
// PRODUCTIVITY RECORD CARD
// ==========================================

class _ProductivityRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;

  const _ProductivityRecordCard({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final profit = _toDouble(record['estimated_profit']);
    final isProfit = profit >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFFD5E8D4),
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withOpacity(0.08),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECTION TITLE
          Row(
            children: [
              const Icon(
                Icons.spa_rounded,
                color: primaryGreen,
                size: 32,
              ),
              const SizedBox(width: 12),
              const Text(
                'Productivity Records',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Divider(
                  color: Color(0xFFB8D8B7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CROP NAME AND DATE
                  Row(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2D9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.grass_rounded,
                          color: primaryGreen,
                          size: 55,
                        ),
                      ),
                      const SizedBox(width: 17),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${record['crop_name'] ?? 'Crop'} • ${record['harvest_date'] ?? ''}',
                              style: const TextStyle(
                                color: darkGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F4E3),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'Date Recorded: ${_date(record['created_at'])}',
                                style: const TextStyle(
                                  color: darkGreen,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _ProductivityMetrics(
                    record: record,
                    compact: compact,
                  ),
                ],
              );

              final profitPanel = _ProfitPanel(
                value: peso(record['estimated_profit']),
                isProfit: isProfit,
              );

              if (compact) {
                return Column(
                  children: [
                    details,
                    const SizedBox(height: 20),
                    profitPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: details,
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    flex: 3,
                    child: profitPanel,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PRODUCTIVITY METRICS
// ==========================================

class _ProductivityMetrics extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool compact;

  const _ProductivityMetrics({
    required this.record,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        Icons.grass_rounded,
        'Harvested Quantity',
        '${record['harvested_sacks'] ?? '—'} sacks',
      ),
      _MetricData(
        Icons.shopping_cart_rounded,
        'Sold Quantity',
        '${record['sold_sacks'] ?? '—'} sacks',
      ),
      _MetricData(
        Icons.payments_rounded,
        'Total Income / Sales',
        peso(record['total_sales']),
      ),
      _MetricData(
        Icons.receipt_long_rounded,
        'Expenses',
        peso(record['production_cost']),
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (final item in items)
            _ProductivityMetric(
              icon: item.icon,
              label: item.label,
              value: item.value,
            ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              for (final item in items.take(2))
                _ProductivityMetric(
                  icon: item.icon,
                  label: item.label,
                  value: item.value,
                ),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 130,
          margin: const EdgeInsets.symmetric(horizontal: 15),
          color: const Color(0xFFB8D8B7),
        ),
        Expanded(
          child: Column(
            children: [
              for (final item in items.skip(2))
                _ProductivityMetric(
                  icon: item.icon,
                  label: item.label,
                  value: item.value,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final String value;

  const _MetricData(this.icon, this.label, this.value);
}

class _ProductivityMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProductivityMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF7E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: primaryGreen,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF52665B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF17251E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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

// ==========================================
// NET PROFIT / LOSS PANEL
// ==========================================

class _ProfitPanel extends StatelessWidget {
  final String value;
  final bool isProfit;

  const _ProfitPanel({
    required this.value,
    required this.isProfit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 260,
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEDF8E9),
            Color(0xFFDFF0D9),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 45,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            isProfit ? 'Net Profit' : 'Net Loss',
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: darkGreen,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 13),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isProfit
                  ? const Color(0xFFD1EBCB)
                  : const Color(0xFFF8DEDE),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isProfit
                      ? Icons.check_circle
                      : Icons.warning_rounded,
                  color: isProfit
                      ? darkGreen
                      : Colors.red.shade800,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  isProfit
                      ? 'Profitable Record'
                      : 'Loss Record',
                  style: TextStyle(
                    color: isProfit
                        ? darkGreen
                        : Colors.red.shade800,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

// ==========================================
// EMPTY HISTORY
// ==========================================

class _EmptyHistory extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyHistory({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(35),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFDCE9DD),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 45,
            color: const Color(0xFF83B889),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64756A),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DATE FORMAT
// ==========================================

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _date(dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return 'Not available';
  }

  final parsed = DateTime.tryParse(value.toString());

  if (parsed == null) return value.toString();

  return '${parsed.year}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')} '
      '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}