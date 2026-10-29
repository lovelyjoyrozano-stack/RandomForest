import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/farm_store.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});

  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen> {
  final FarmStore store = FarmStore.instance;
  final _formKey = GlobalKey<FormState>();
  final _crop = TextEditingController(text: 'Rice');
  final _harvested = TextEditingController();
  final _sold = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();

  DateTime _harvestDate = DateTime.now();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _crop.dispose();
    _harvested.dispose();
    _sold.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  String? _requiredInt(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    return (n == null || n < 0) ? 'Enter a whole number (0 or more)' : null;
  }

  String? _requiredMoney(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    return (n == null || n < 0) ? 'Enter an amount (0 or more)' : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _harvestDate = picked);
  }

  Future<void> _submit() async {
    final farm = store.selected;
    if (farm == null || !_formKey.currentState!.validate()) return;

    final harvested = int.parse(_harvested.text.trim());
    final sold = int.parse(_sold.text.trim());
    if (sold > harvested) {
      setState(() => _error = 'Sold sacks cannot be greater than harvested sacks.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await ApiClient.instance.post('/productivity/evaluate', body: {
        'farm_id': farm.id,
        'crop_name': _crop.text.trim(),
        'harvested_sacks': harvested,
        'sold_sacks': sold,
        'price_per_sack': double.parse(_price.text.trim()),
        'production_cost': double.parse(_cost.text.trim()),
        'harvest_date': isoDate(_harvestDate),
      });
      if (!mounted) return;
      setState(() => _result = Map<String, dynamic>.from(data as Map));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    _harvested.clear();
    _sold.clear();
    _price.clear();
    _cost.clear();
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Productivity')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.selected == null) {
            return const Center(child: Text('Register a farm first.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Harvest and Sales Information',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Enter your harvest, sales and production expenses.'),
                  const SizedBox(height: 18),
                  FarmSelectorBar(store: store),
                  const SizedBox(height: 14),
                  _field('Crop name', _crop,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the crop'
                          : null),
                  _field('Harvested sacks', _harvested,
                      keyboard: TextInputType.number, validator: _requiredInt),
                  _field('Sold sacks', _sold,
                      keyboard: TextInputType.number, validator: _requiredInt),
                  _field('Price per sack (₱)', _price,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      validator: _requiredMoney),
                  _field('Total production cost (₱)', _cost,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                      validator: _requiredMoney),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Harvest date'),
                    subtitle: Text(isoDate(_harvestDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading ? 'Saving...' : 'Evaluate & Save'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    ErrorBanner(_error!),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 22),
                    _resultCard(_result!),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final status = r['performance_status']?.toString() ?? 'N/A';
    final profit = asDouble(r['estimated_profit']) ?? 0;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor(status), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Productivity Result',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              ),
              StatusBadge(status),
            ]),
            const SizedBox(height: 10),
            Text(r['performance_message']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (r['performance_message_en'] != null)
              Text(r['performance_message_en'].toString(),
                  style: const TextStyle(color: Colors.black54)),
            const Divider(height: 24),
            MetricRow('Crop', r['crop_name']?.toString() ?? '-'),
            MetricRow('Harvested', '${r['harvested_sacks'] ?? 0} sacks'),
            MetricRow('Sold', '${r['sold_sacks'] ?? 0} sacks'),
            MetricRow('Sales', peso(r['total_sales'])),
            MetricRow('Production cost', peso(r['production_cost'])),
            MetricRow(profit >= 0 ? 'Profit' : 'Loss', peso(profit), bold: true),
            if (r['roi_percent'] != null)
              MetricRow('Return on cost', '${num1(r['roi_percent'])}%'),
            if (r['yield_sacks_per_ha'] != null)
              MetricRow('Yield', '${num1(r['yield_sacks_per_ha'])} sacks/ha'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reset, child: const Text('Add another')),
          ],
        ),
      ),
    );
  }
}
