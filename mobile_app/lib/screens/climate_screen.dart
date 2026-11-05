import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const _kDeep = Color(0xFF0E4D32);
const _kMuted = Color(0xFF5B6B62);
const _kBg = Color(0xFFF3F8F4);
const _kBorder = Color(0xFFDCEBDD);
const _kTint = Color(0xFFE6F2E8);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtHour(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_two(t.minute)} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

String _fmtDateTime(DateTime t) =>
    '${_months[t.month - 1]} ${t.day}, ${t.year} ${_two(t.hour == 0 || t.hour == 12 ? 12 : t.hour % 12)}:${_two(t.minute)} ${t.hour >= 12 ? 'PM' : 'AM'}';

/// Backend timestamps are UTC (OpenWeather `dt_txt`, DB `created_at`).
DateTime? _parseUtc(String? s) {
  if (s == null || s.isEmpty) return null;
  var v = s.replaceFirst(' ', 'T');
  if (!RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(v)) v = '${v}Z';
  return DateTime.tryParse(v)?.toLocal();
}

class ClimateScreen extends StatefulWidget {
  const ClimateScreen({super.key});

  @override
  State<ClimateScreen> createState() => _ClimateScreenState();
}

class _ClimateScreenState extends State<ClimateScreen> {
  final FarmStore store = FarmStore.instance;

  // Everything on this screen re-fetches at this interval (backend caches 60s).
  static const Duration _refreshEvery = Duration(seconds: 60);

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _advice;
  List<Map<String, dynamic>> _forecasts = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _weather;
  DateTime? _lastUpdated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (store.selected != null) _load();
    _timer = Timer.periodic(_refreshEvery, (_) {
      if (mounted && store.selected != null && !_loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _weatherIconWidget(String? condition, {double size = 40}) {
    final weather = (condition ?? '').toLowerCase();

  if (weather.contains('thunder')) {
    return Icon(
      Icons.thunderstorm_rounded,
      size: size,
      color: Colors.deepPurple,
    );
  }

  if (weather.contains('rain') || weather.contains('drizzle')) {
    return Image.asset(
      'assets/images/rainy.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        Icons.umbrella_rounded,
        size: size,
        color: Colors.blue,
      ),
    );
  }

  if (weather.contains('snow') || weather.contains('sleet')) {
    return Icon(
      Icons.ac_unit_rounded,
      size: size,
      color: Colors.lightBlue,
    );
  }

  if (weather.contains('fog') ||
      weather.contains('mist') ||
      weather.contains('haze') ||
      weather.contains('smoke')) {
    return Icon(
      Icons.foggy,
      size: size,
      color: Colors.blueGrey,
    );
  }

  if (weather.contains('clear') || weather.contains('sun')) {
    return Icon(
      Icons.wb_sunny_rounded,
      size: size,
      color: Colors.orange,
    );
  }

  if (weather.contains('cloud')) {
    return Icon(
      Icons.cloud_rounded,
      size: size,
      color: Colors.blueGrey,
    );
  }

  return Icon(
    Icons.wb_cloudy_outlined,
    size: size,
    color: Colors.blueGrey,
  );
}


  Future<void> _load({bool silent = false}) async {
    final farm = store.selected;
    if (farm == null) return;

    setState(() {
      _loading = true;
      if (!silent) _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.instance
            .get('/climate/planting-advice', query: {'farm_id': farm.id}),
        ApiClient.instance
            .get('/climate/current-weather', query: {'farm_id': farm.id}),
        ApiClient.instance
            .get('/climate/history', query: {'farm_id': farm.id, 'limit': 7}),
      ]);
      final advice = Map<String, dynamic>.from(results[0] as Map);
      final current = Map<String, dynamic>.from(results[1] as Map);
      final historyData = results[2] as Map;
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _forecasts = (advice['forecasts'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _history = (historyData['readings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _weather = current;
        _lastUpdated = DateTime.now();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silent) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFarmChanged() {
    setState(() {
      _advice = null;
      _weather = null;
      _forecasts = [];
      _history = [];
    });
    _load();
  }

  // Display only readings saved within the last 24 hours.
List<Map<String, dynamic>> get _recentHistory {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(hours: 24));

  return _history.where((reading) {
    final savedAt = _parseUtc(reading['created_at']?.toString());

    return savedAt != null &&
        !savedAt.isBefore(cutoff) &&
        !savedAt.isAfter(now);
  }).toList();
}

String _heatWarning(double temperature) {
  if (temperature >= 38) {
    return 'Extreme Heat Alert';
  } else if (temperature >= 35) {
    return 'High Temperature Alert';
  }
  return 'No Heat Warning';
}

Color _heatWarningColor(double temperature) {
  if (temperature >= 38) return Colors.red.shade700;
  if (temperature >= 35) return Colors.orange.shade800;
  return Colors.green.shade700;
}

Widget _heatWarningPanel() {
  final rawTemperature = _weather?['temperature_celsius'];
  final temperature = rawTemperature is num
      ? rawTemperature.toDouble()
      : double.tryParse(rawTemperature?.toString() ?? '');

  if (temperature == null) {
    return const SizedBox.shrink();
  }

  final warning = _heatWarning(temperature);
  final isExtreme = temperature >= 38;
  final isHigh = temperature >= 35 && temperature < 38;

  final color = _heatWarningColor(temperature);

  return _panel(
    icon: Icons.thermostat,
    title: 'Heat Warning',
    subtitle: 'Based on the latest current temperature.',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isExtreme
                ? Icons.warning_rounded
                : isHigh
                    ? Icons.thermostat
                    : Icons.check_circle_outline,
            color: color,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${temperature.toStringAsFixed(1)}°C current temperature',
                  style: const TextStyle(color: _kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  body: Stack(
    children: [
      Positioned.fill(
  child: Image.asset(
     'assets/images/climate_monitoring.png',
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      color:  _kBg,
    ),
  ),
),
      
      SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            if (store.selected == null) {
              return const Center(child: Text('Register a farm first.'));
            }
            return RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 820;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  children: [
                    _header(wide),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ErrorBanner(_error!, onRetry: _load),
                      ),
                    if (_loading && _weather == null)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_weather != null) _currentWeatherPanel(_weather!, wide),
                    if (_weather != null) _heatWarningPanel(),
                    if (_forecasts.isNotEmpty) _forecastPanel(),
                    if (_advice != null) _advicePanel(_advice!, wide),
                    if (_recentHistory.isNotEmpty) _historyPanel(),
                  ],
                );
              }),
            );
          },
        ),
      ),
    ],
  ),
);
}
  
   

  Widget _header(bool wide) {
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Climate Monitoring',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _kDeep)),
              SizedBox(height: 4),
              Text(
                'Monitor weather conditions and forecasts to make better farming decisions.',
                style: TextStyle(color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );

    final refresh = OutlinedButton.icon(
      onPressed: _loading ? null : _load,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, size: 18),
      label: const Text('Refresh Data'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kDeep,
        side: const BorderSide(color: _kBorder),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: FarmSelectorBar(
                store: store, onChanged: (_) => _onFarmChanged()),
          ),
          const SizedBox(width: 12),
          refresh,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 12),
        FarmSelectorBar(store: store, onChanged: (_) => _onFarmChanged()),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: refresh),
      ],
    );
  }

  // ───────────────────────── panels ─────────────────────────

  Widget _panel({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFEFF7F1)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 34, color: _kDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _kDeep)),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: _kMuted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Current weather ──

  Widget _currentWeatherPanel(Map<String, dynamic> w, bool wide) {
    final main = w['weather_main']?.toString();
    final observed = w['observed_at'];
    final updated = observed is num
        ? DateTime.fromMillisecondsSinceEpoch(observed.toInt() * 1000)
        : _lastUpdated;

    final temperature = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: _kTint,
            borderRadius: BorderRadius.circular(28),
          ),
         child: Center(
  child: _weatherIconWidget(main, size: 76),
),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: num1(w['temperature_celsius']),
                    style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        color: _kDeep)),
                const TextSpan(
                    text: '°C',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _kDeep)),
              ])),
              Text(capitalize(w['weather_condition']?.toString() ?? 'Unknown'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _kDeep)),

            ],
          ),
        ),
      ],
    );

    final metrics = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metric(Icons.water_drop_outlined, 'Humidity',
            '${num1(w['humidity_percent'], 0)}%'),
        _metric(Icons.air, 'Wind Speed', '${num1(w['wind_speed_ms'])} m/s'),
        _metric(Icons.umbrella_outlined, 'Rainfall (current)',
            '${num1(w['rainfall_mm'] ?? 0)} mm'),
        _metric(Icons.access_time, 'Last Updated',
            updated == null ? '-' : _fmtDateTime(updated)),
      ],
    );

    final photo = _fieldPhoto(w['city']?.toString() ?? '');

    return _panel(
      icon: Icons.wb_cloudy_outlined,
      title: 'Current Weather',
      subtitle: 'Latest weather conditions in your area.',
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: temperature),
                Container(
                    width: 1,
                    height: 170,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: _kBorder),
                Expanded(flex: 3, child: metrics),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: photo),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                temperature,
                const Divider(height: 28),
                metrics,
                const SizedBox(height: 12),
                photo,
              ],
            ),
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: _kDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _kMuted)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _kDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Uses assets/images/rice_field.jpg when present; otherwise a green fallback.
  Widget _fieldPhoto(String city) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9CCBE8), Color(0xFF7DB36A), Color(0xFF4E8F3A)],
        ),
      ),
      child: const Center(
          child: Icon(Icons.grass, size: 72, color: Colors.white70)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/rice_field.png',
                fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kDeep.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on,
                        size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(city,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Forecast ──

  /// Live strip: a "Now" card built from the current weather, followed by the
  /// upcoming 3-hour forecast blocks. Blocks whose time has already passed are
  /// dropped, so the strip always starts at the present moment.
  List<Map<String, dynamic>> _liveForecastItems() {
    final now = DateTime.now();
    final upcoming = _forecasts.where((f) {
      final t = _parseUtc(f['date_time']?.toString());
      return t != null && t.isAfter(now);
    }).toList();

    final items = <Map<String, dynamic>>[];
    final w = _weather;
    if (w != null) {
      items.add({
        'is_now': true,
        'weather_main': w['weather_main'],
        'weather_condition': w['weather_condition'],
        'temperature_celsius': w['temperature_celsius'],
        'rainfall_mm': w['rainfall_mm'] ?? 0,
      });
    }
    items.addAll(upcoming);
    return items.take(8).toList();
  }

  Widget _forecastPanel() {
    final items = _liveForecastItems();
    return _panel(
      icon: Icons.schedule,
      title: 'Next 24 Hours Forecast',
      subtitle: 'Live now, then the upcoming hours. Updates every minute.',
      child: LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final n = items.length;
        final fit = (c.maxWidth - gap * (n - 1)) / n;
        final w = fit < 104 ? 104.0 : fit;
        return SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: n,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (_, i) => _forecastCard(items[i], w, i == 0),
          ),
        );
      }),
    );
  }

  Widget _forecastCard(Map<String, dynamic> f, double width, bool first) {
    final isNow = f['is_now'] == true;
    final t = _parseUtc(f['date_time']?.toString());
    final main = f['weather_main']?.toString();
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: first ? _kTint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: first ? _kDeep.withValues(alpha: 0.35) : _kBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isNow ? 'Now' : (t == null ? '-' : _fmtHour(t)),
              style: TextStyle(
                  fontSize: 12,
                  color: _kDeep,
                  fontWeight: isNow ? FontWeight.bold : FontWeight.normal)),
          _weatherIconWidget(main, size: 34),
          Text(capitalize(f['weather_condition']?.toString() ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _kMuted)),
          Text('${num1(f['temperature_celsius'], 0)}°C',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _kDeep)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop_outlined,
                  size: 13, color: Color(0xFF2B7BB9)),
              const SizedBox(width: 3),
              Text('${num1(f['rainfall_mm'])} mm',
                  style: const TextStyle(fontSize: 11, color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Planting advice ──

  
Widget _advicePanel(Map<String, dynamic> a, bool wide) {
  final status = a['planting_status']?.toString() ?? 'N/A';

  double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  final temperature = toDouble(
    a['current_temperature_c'] ?? a['average_temperature_c'],
  );
  final rainfall = toDouble(a['current_rainfall_mm']);
  final humidity = toDouble(
    a['current_humidity_percent'] ?? a['average_humidity_percent'],
  );
  final rainChance = toDouble(
    a['maximum_rain_probability_percent'],
  );
  final conditions =
      capitalize(a['weather_condition']?.toString() ?? '-');

  final unsuitable = status.toLowerCase().contains('not suitable') ||
      status.toLowerCase().contains('unsuitable');

  // Determine the main reason using the existing climate thresholds.
  String reasonTitle = 'Reason for Recommendation';
  String reasonDetail = a['reason']?.toString() ??
      'Weather conditions were evaluated using the current readings and forecast.';

  if (rainChance >= 80) {
    reasonDetail =
        'High probability of rainfall detected. The maximum rain chance is ${rainChance.toStringAsFixed(0)}%, which exceeds the recommended threshold of 80%.';
  } else if (rainfall >= 50) {
    reasonDetail =
        'Heavy rainfall is expected. The forecast rainfall of ${rainfall.toStringAsFixed(1)} mm exceeds the 50 mm threshold.';
  } else if (temperature >= 38) {
    reasonDetail =
        'Extreme temperature detected. The current temperature of ${temperature.toStringAsFixed(1)}°C exceeds the recommended 38°C threshold.';
  } else if (rainChance >= 50) {
    reasonDetail =
        'There is a high chance of rain. Monitor the forecast and check the soil condition before planting.';
  }

  final action = rainChance >= 80
      ? 'Consider postponing planting and monitor the weather forecast before proceeding.'
      : rainfall >= 50
          ? 'Check field drainage and wait until excess water has drained before planting.'
          : temperature >= 38
              ? 'Avoid planting during extreme heat. Wait for cooler conditions.'
              : unsuitable
                  ? 'Check your field conditions and consult your local agriculture office before planting.'
                  : 'Continue monitoring weather conditions and prepare your field for planting.';

  // UI-only status styling. Existing status, values, reasons, and actions above remain unchanged.
  final isCaution = status.toLowerCase().contains('caution');
  final Color accent = unsuitable
      ? const Color(0xFFB42318)
      : isCaution
          ? const Color(0xFFB7791F)
          : const Color(0xFF278044);
  final Color soft = unsuitable
      ? const Color(0xFFFFEEEE)
      : isCaution
          ? const Color(0xFFFFF6DF)
          : const Color(0xFFEAF7EC);
  final Color outline = unsuitable
      ? const Color(0xFFF3C5C1)
      : isCaution
          ? const Color(0xFFF0D99B)
          : const Color(0xFFC8E7CE);

  final String statusMessage = unsuitable
      ? 'Unfavorable weather conditions detected. Consider postponing planting until conditions improve.'
      : isCaution
          ? 'Some weather conditions may affect planting. Proceed with caution and monitor the forecast.'
          : 'Favorable weather conditions detected. You may proceed with planting.';

  final String plantingImage = unsuitable
      ? 'assets/images/not_suitable.png'
      : isCaution
          ? 'assets/images/caution.png'
          : 'assets/images/suitable.png';

  final badge = Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          unsuitable
              ? Icons.cancel_rounded
              : isCaution
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget factorCard(
    IconData icon,
    String label,
    String value,
    String condition,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _kMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _kDeep,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            condition,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  final factors = [
    factorCard(
      Icons.thermostat,
      'Temperature',
      '${temperature.toStringAsFixed(1)}°C',
      temperature >= 38 ? 'Too High' : 'Normal',
      temperature >= 38 ? Colors.red : Colors.green,
    ),
    factorCard(
      Icons.water_drop_outlined,
      'Rainfall',
      '${rainfall.toStringAsFixed(1)} mm',
      rainfall >= 50 ? 'Too High' : 'Current',
      rainfall >= 50 ? Colors.red : Colors.blue,
    ),
    factorCard(
      Icons.water,
      'Humidity',
      '${humidity.toStringAsFixed(0)}%',
      humidity >= 85 ? 'High' : 'Normal',
      humidity >= 85 ? Colors.orange : Colors.green,
    ),
    factorCard(
      Icons.cloudy_snowing,
      'Max Rain Chance',
      '${rainChance.toStringAsFixed(0)}%',
      rainChance >= 80 ? 'Too High' : 'Normal',
      rainChance >= 80 ? Colors.red : Colors.green,
    ),
    factorCard(
      Icons.wb_cloudy_outlined,
      'Conditions',
      conditions,
      'Current',
      Colors.blueGrey,
    ),
  ];

  final illustration = ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: wide ? 170 : double.infinity,
      height: wide ? 170 : 165,
      child: Image.asset(
        plantingImage,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: soft,
          alignment: Alignment.center,
          child: Icon(
            unsuitable
                ? Icons.thunderstorm_rounded
                : isCaution
                    ? Icons.cloudy_snowing
                    : Icons.wb_sunny_rounded,
            size: 76,
            color: accent,
          ),
        ),
      ),
    ),
  );

  final statusMessagePanel = Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: outline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          unsuitable
              ? Icons.cancel_rounded
              : isCaution
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
          color: accent,
          size: 21,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            statusMessage,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  final reasonPanel = Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: outline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          unsuitable
              ? Icons.error_rounded
              : isCaution
                  ? Icons.info_rounded
                  : Icons.check_circle_rounded,
          color: accent,
          size: 21,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reasonTitle,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reasonDetail,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final recommendedAction = Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: soft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: outline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_rounded, color: accent, size: 25),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommended Action',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action,
                style: TextStyle(
                  fontSize: 12,
                  color: accent.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget weatherFactors({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weather Factors That Caused This Result',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _kDeep,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final itemWidth = compact
                ? (constraints.maxWidth - gap) / 2
                : (constraints.maxWidth - gap * 4) / 5;
            return Wrap(
              spacing: gap,
              runSpacing: 8,
              children: [
                for (final factor in factors)
                  SizedBox(width: itemWidth, child: factor),
              ],
            );
          },
        ),
      ],
    );
  }

  return _panel(
    icon: Icons.eco_outlined,
    title: 'General Planting Recommendation',
    subtitle: 'Based on current weather and the next 24 hours forecast.',
    trailing: badge,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              illustration,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statusMessagePanel,
                    const SizedBox(height: 10),
                    reasonPanel,
                    const SizedBox(height: 12),
                    weatherFactors(compact: false),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              illustration,
              const SizedBox(height: 12),
              statusMessagePanel,
              const SizedBox(height: 10),
              reasonPanel,
              const SizedBox(height: 12),
              weatherFactors(compact: true),
            ],
          ),
        const SizedBox(height: 12),
        recommendedAction,
      ],
    ),
  );
}


// ── History ──

  Widget _historyPanel() {
    const head = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: _kDeep);

    Widget row(List<Widget> cells, {Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: cells),
        );

    return _panel(
      icon: Icons.history,
      title: 'Recent Saved Readings',
      subtitle: 'Readings saved within the last 24 hours',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              row(const [
                Expanded(flex: 4, child: Text('Date & Time', style: head)),
                Expanded(flex: 4, child: Text('Weather', style: head)),
                Expanded(flex: 2, child: Text('Temp', style: head)),
                Expanded(flex: 2, child: Text('Humidity', style: head)),
                Expanded(flex: 2, child: Text('Rainfall', style: head)),
              ], bg: _kTint),
              for (final h in _recentHistory)
                Column(
                  children: [
                    const Divider(height: 1, color: _kBorder),
                    row([
                      Expanded(
                        flex: 4,
                        child: Text(
                          () {
                            final t = _parseUtc(h['created_at']?.toString());
                            return t == null ? '-' : _fmtDateTime(t);
                          }(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                           _weatherIconWidget(
  h['weather_condition']?.toString(),
  size: 20,
),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                capitalize(
                                    h['weather_condition']?.toString() ?? ''),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                          flex: 2,
                          child: Text('${num1(h['temperature'])}°C',
                              style: const TextStyle(fontSize: 12))),
                      Expanded(
                          flex: 2,
                          child: Text('${num1(h['humidity'], 0)}%',
                              style: const TextStyle(fontSize: 12))),
                      Expanded(
                          flex: 2,
                          child: Text('${num1(h['rainfall'])} mm',
                              style: const TextStyle(fontSize: 12))),
                    ]),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}