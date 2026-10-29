import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'dart:async';

class ClimateScreen extends StatefulWidget {
  const ClimateScreen({super.key});

  @override
  State<ClimateScreen> createState() => _ClimateScreenState();
  
}

class _ClimateScreenState extends State<ClimateScreen> {
  final FarmStore store = FarmStore.instance;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _advice;
  List<Map<String, dynamic>> _forecasts = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _currentWeather;
  Timer? _weatherRefreshTimer;

  @override
  void initState() {
    super.initState();

  if (store.selected != null) {
    _load();
  }

  _weatherRefreshTimer = Timer.periodic(
    const Duration(minutes: 5),
    (_) {
      if (mounted && store.selected != null && !_loading) {
        _load();
      }
    },
  );
}

@override
void dispose() {
  _weatherRefreshTimer?.cancel();
  super.dispose();
}


  Future<void> _load() async {
    final farm = store.selected;
    if (farm == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // One call returns the advice and the forecast, so the weather API is hit once.
      final adviceData = await ApiClient.instance
          .get('/climate/planting-advice', query: {'farm_id': farm.id});
      final currentWeatherData = await ApiClient.instance.get(
  '/climate/current-weather',
  query: {'farm_id': farm.id},
);
      final historyData = await ApiClient.instance
          .get('/climate/history', query: {'farm_id': farm.id, 'limit': 7});

      final advice = Map<String, dynamic>.from(adviceData as Map);
      if (!mounted) return;
      setState(() {
        _forecasts = (advice['forecasts'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _advice = advice;
        _history = ((historyData as Map)['readings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _currentWeather = 
        Map<String, dynamic>.from(currentWeatherData as Map);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Climate Monitoring')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.selected == null) {
            return const Center(child: Text('Register a farm first.'));
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                FarmSelectorBar(
                  store: store,
                  onChanged: (_) {
                    setState(() {
                      _advice = null;
                      _forecasts = [];
                      _history = [];
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(_loading ? 'Loading...' : 'Check Climate'),
                ),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator())),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ErrorBanner(_error!, onRetry: _load),
                  ),
                if (_advice != null) ..._adviceSection(_advice!),
                if (_history.isNotEmpty) ..._historySection(),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _adviceSection(Map<String, dynamic> a) {
    final status = a['planting_status']?.toString() ?? 'N/A';
    final now = _currentWeather ??
    (_forecasts.isNotEmpty ? _forecasts.first : <String, dynamic>{});

final nowMain = now['weather_main']?.toString();
final temperature = double.tryParse(
  now['temperature_celsius']?.toString() ?? '',
);

final bool extremeHeat = temperature != null && temperature >= 38;
final bool highHeat =
    temperature != null && temperature >= 35 && temperature < 38;
    final conditions =
        (a['conditions_24h'] as List? ?? []).map((e) => e.toString()).toList();

    return [
      if (extremeHeat || highHeat)
  Card(
    color: extremeHeat
        ? Colors.red.shade100
        : Colors.orange.shade100,
    child: ListTile(
      leading: Icon(
        Icons.warning_amber_rounded,
        color: extremeHeat ? Colors.red : Colors.deepOrange,
        size: 32,
      ),
      title: Text(
        extremeHeat
            ? 'Extreme Heat Alert!'
            : 'High Temperature Alert!',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: extremeHeat ? Colors.red.shade900 : Colors.deepOrange,
        ),
      ),
      subtitle: Text(
        extremeHeat
            ? 'Temperature is ${temperature.toStringAsFixed(1)}°C. ' 
                'Monitor your crops and soil moisture carefully.'
            : 'Temperature is ${temperature.toStringAsFixed(1)}°C. '
               'Check your crops and make sure they have enough water.',
      ),
    ),
  ),
      
      const SizedBox(height: 18),
            Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weather now',
                  style: TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(weatherIcon(nowMain),
                      size: 56, color: weatherColor(nowMain)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          capitalize(now['weather_condition']?.toString() ?? 'Unknown'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text('${num1(now['temperature_celsius'])} °C'
                            '${now['feels_like_celsius'] != null ? '  (feels like ${num1(now['feels_like_celsius'])} °C)' : ''}'),
                        if (now['wind_speed_ms'] != null)
                          Text('Wind ${num1(now['wind_speed_ms'])} m/s • '
                              'Humidity ${num1(now['humidity_percent'], 0)}%'),
                      ],
                    ),
                  ),
                ],
              ),
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Expected in the next 24 hours',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in conditions) Chip(label: Text(capitalize(c))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
   // katapusan sa Weather now card (line 176)
      const SizedBox(height: 8),   // <- idugang
      Card(                        // Planting Advice card
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: statusColor(status), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Rice Planting Advice',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                  ),
                  StatusBadge(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(a['city']?.toString() ?? '',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Text(a['reason']?.toString() ?? ''),
              const Divider(height: 24),
              MetricRow('Avg temperature',
                  '${num1(a['average_temperature_c'])} °C'),
              MetricRow('Rain (next 24h)',
                  '${num1(a['forecast_rainfall_mm'])} mm'),
              MetricRow('Avg humidity',
                  '${num1(a['average_humidity_percent'], 0)}%'),
              MetricRow('Max rain chance',
                  '${num1(a['maximum_rain_probability_percent'], 0)}%'),
              MetricRow('Conditions', a['weather_condition']?.toString() ?? '-'),
              const SizedBox(height: 8),
              const Text(
                'Advice is rule-based and preliminary. Confirm with your '
                'local agriculture office and check your field.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
            const SectionTitle('Next 24 hours'),
      for (final f in _forecasts)
        Card(
          child: ListTile(
            leading: Icon(
              weatherIcon(f['weather_main']?.toString()),
              size: 30,
              color: weatherColor(f['weather_main']?.toString()),
            ),
            title: Text(
                '${capitalize(f['weather_condition']?.toString() ?? 'Unknown')} — ${num1(f['temperature_celsius'])} °C'),
            subtitle: Text(
                '${f['date_time'] ?? ''}\nRain: ${num1(f['rainfall_mm'])} mm • '
                'Chance: ${f['rain_probability_percent'] ?? 0}%'),
            isThreeLine: true,
          ),
        ),
    ];
  }

  List<Widget> _historySection() {
    return [
      const SectionTitle('Recent saved readings'),
      for (final h in _history)
        Card(
          child: ListTile(
            dense: true,
             title: Text(
              '${capitalize(h['weather_condition']?.toString() ?? '')} • ${num1(h['temperature'])} °C • ${num1(h['rainfall'])} mm • ${num1(h['humidity'], 0)}%'),
            subtitle: Text(
                (h['created_at']?.toString() ?? '').replaceFirst('T', ' ').split('.').first),
            trailing: h['planting_status'] == null
                ? null
                : Text(h['planting_status'].toString(),
                    style: TextStyle(
                        color: statusColor(h['planting_status'].toString()),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
          ),
        ),
    ];
  }
}
