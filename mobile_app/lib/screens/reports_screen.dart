import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = FarmStore.instance;
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: AppBar(title: const Text('Weather & Productivity Record History'), bottom: const TabBar(
        tabs: [Tab(icon: Icon(Icons.cloud_outlined), text: 'Weather History'), Tab(icon: Icon(Icons.agriculture), text: 'Productivity History')],
      )),
      body: ListenableBuilder(listenable: store, builder: (context, _) {
        final farm = store.selected;
        if (farm == null) return const Center(child: Text('Register a farm first.'));
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: FarmSelectorBar(store: store)),
          Expanded(child: TabBarView(key: ValueKey(farm.id), children: [
            _WeatherHistoryTab(farmId: farm.id, location: farm.city?.isNotEmpty == true ? farm.city! : farm.location),
            _ProductivityHistoryTab(farmId: farm.id),
          ])),
        ]);
      }),
    ));
  }
}

class _WeatherHistoryTab extends StatefulWidget {
  final int farmId;
  final String location;
  const _WeatherHistoryTab({required this.farmId, required this.location});
  @override
  State<_WeatherHistoryTab> createState() => _WeatherHistoryTabState();
}
class _WeatherHistoryTabState extends State<_WeatherHistoryTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient.instance.get('/climate/history', query: {'farm_id': widget.farmId, 'limit': 365});
      final list = (result as Map)['readings'] as List? ?? [];
      if (mounted) setState(() => _records = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on ApiException catch (e) { if (mounted) setState(() => _error = e.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
      if (_error != null) ErrorBanner(_error!, onRetry: _load),
      if (_records.isEmpty && _error == null) const Padding(padding: EdgeInsets.all(30), child: Text('No weather records found', textAlign: TextAlign.center)),
      for (final r in _records) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        MetricRow('Temperature', '${r['temperature'] ?? '—'} °C'),
        MetricRow('Humidity', '${r['humidity'] ?? '—'} %'),
        MetricRow('Rainfall', '${r['rainfall'] ?? '—'} mm'),
        MetricRow('Condition', '${r['weather_condition'] ?? 'Unknown'}'),
        MetricRow('Rain probability', '${r['rain_probability'] ?? '—'} %'),
        MetricRow('Date recorded', _date(r['created_at'])),
      ]))),
    ]));
  }
}

class _ProductivityHistoryTab extends StatefulWidget {
  final int farmId;
  const _ProductivityHistoryTab({required this.farmId});
  @override
  State<_ProductivityHistoryTab> createState() => _ProductivityHistoryTabState();
}
class _ProductivityHistoryTabState extends State<_ProductivityHistoryTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient.instance.get('/productivity/records', query: {'farm_id': widget.farmId, 'limit': 500});
      final list = (result as Map)['records'] as List? ?? [];
      if (mounted) setState(() => _records = list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on ApiException catch (e) { if (mounted) setState(() => _error = e.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
      if (_error != null) ErrorBanner(_error!, onRetry: _load),
      if (_records.isEmpty && _error == null) const Padding(padding: EdgeInsets.all(30), child: Text('No productivity records found', textAlign: TextAlign.center)),
      for (final r in _records) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['crop_name'] ?? 'Crop'} • ${r['harvest_date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        MetricRow('Harvested quantity', '${r['harvested_sacks'] ?? '—'} sacks'),
        MetricRow('Sold quantity', '${r['sold_sacks'] ?? '—'} sacks'),
        MetricRow('Total income / sales', peso(r['total_sales'])),
        MetricRow('Expenses', peso(r['production_cost'])),
        MetricRow('Profit / loss', peso(r['estimated_profit']), bold: true),
        MetricRow('Date recorded', _date(r['created_at'])),
      ]))),
    ]));
  }
}

String _date(dynamic value) {
  if (value == null || value.toString().isEmpty) return 'Not available';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}
