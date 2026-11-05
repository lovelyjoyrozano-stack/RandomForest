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

  static const Color _darkGreen = Color(0xFF124B30);
  static const Color _green = Color(0xFF24764B);
  static const Color _pageBg = Color(0xFFF5F8F4);
  static const Color _border = Color(0xFFDCE6DB);
  static const Color _muted = Color(0xFF758579);

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
    return (n == null || n < 0)
        ? 'Enter a whole number (0 or more)'
        : null;
  }

  String? _requiredMoney(String? v) {
    final n = double.tryParse(v?.trim() ?? '');
    return (n == null || n < 0)
        ? 'Enter an amount (0 or more)'
        : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _darkGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _submit() async {
    final farm = store.selected;

    if (farm == null || !_formKey.currentState!.validate()) {
      return;
    }

    final harvested = int.parse(_harvested.text.trim());
    final sold = int.parse(_sold.text.trim());

    if (sold > harvested) {
      setState(() {
        _error = 'Sold sacks cannot be greater than harvested sacks.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final data = await ApiClient.instance.post(
        '/productivity/evaluate',
        body: {
          'farm_id': farm.id,
          'crop_name': _crop.text.trim(),
          'harvested_sacks': harvested,
          'sold_sacks': sold,
          'price_per_sack': double.parse(_price.text.trim()),
          'production_cost': double.parse(_cost.text.trim()),
          'harvest_date': isoDate(_harvestDate),
        },
      );

      if (!mounted) return;

      setState(() {
        _result = Map<String, dynamic>.from(data as Map);
      });
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Crop Productivity',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
  children: [
     Positioned.fill(
  child: Image.asset(
     'assets/images/crop_productivity1.png',
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      color:  _pageBg,
    ),
  ),
),

   
    ListenableBuilder(
      listenable: store,
        builder: (context, _) {
          if (store.selected == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.agriculture_outlined,
                      size: 64,
                      color: _green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Register a farm first',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a farm before recording your crop productivity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: _green,
            onRefresh: store.load,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 950;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 20,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1250),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPageHeading(),
                            const SizedBox(height: 22),

                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _buildFormCard(),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 5,
                                    child: _result != null
                                        ? _resultCard(_result!)
                                        : _buildResultPlaceholder(),
                                  ),
                                ],
                              )
                            else ...[
                              _buildFormCard(),
                              if (_result != null) ...[
                                const SizedBox(height: 24),
                                _resultCard(_result!),
                              ],
                            ],

                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              ErrorBanner(_error!),
                            ],

                            const SizedBox(height: 24),
                          ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    ),
  );
}

  Widget _buildPageHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Crop Productivity',
          style: TextStyle(
            color: _darkGreen,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Monitor your harvest, sales, expenses, and farm performance.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0E5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5E4D2)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.agriculture,
                  color: _green,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harvest and Sales Information',
                      style: TextStyle(
                        fontSize: 18,
                        color: _darkGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Enter your harvest, sales and production expenses.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF627767),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: _green, size: 25),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Harvest Details',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Provide the details of your latest harvest.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 22),

          _fieldLabel('Farm'),
          FarmSelectorBar(store: store),
          const SizedBox(height: 18),

          _field(
            'Crop name',
            _crop,
            icon: Icons.grass,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter the crop' : null,
          ),

          _field(
            'Harvested sacks',
            _harvested,
            icon: Icons.inventory_2_outlined,
            keyboard: TextInputType.number,
            validator: _requiredInt,
          ),

          _field(
            'Sold sacks',
            _sold,
            icon: Icons.shopping_bag_outlined,
            keyboard: TextInputType.number,
            validator: _requiredInt,
          ),

          _field(
            'Price per sack (₱)',
            _price,
            icon: Icons.payments_outlined,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: _requiredMoney,
          ),

          _field(
            'Total production cost (₱)',
            _cost,
            icon: Icons.account_balance_wallet_outlined,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            validator: _requiredMoney,
          ),

          const SizedBox(height: 4),
          _fieldLabel('Harvest date'),

          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: _green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harvest date',
                          style: TextStyle(
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isoDate(_harvestDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(
                _loading ? 'Evaluating...' : 'Evaluate & Save',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Review your details before saving.',
              style: TextStyle(
                fontSize: 12,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF44574A),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: _green, size: 21),
          filled: true,
          fillColor: const Color(0xFFFAFCF9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 17,
          ),
          labelStyle: const TextStyle(
            color: _muted,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1E7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.query_stats,
            size: 42,
            color: _green,
          ),
          SizedBox(height: 18),
          Text(
            'Productivity Result',
            style: TextStyle(
              fontSize: 21,
              color: _darkGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your harvest evaluation will appear here after you select a farm, enter your harvest information, and tap Evaluate & Save.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF66786A),
            ),
          ),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 12),
          _PlaceholderMetric(
            icon: Icons.payments_outlined,
            label: 'Total sales',
          ),
          _PlaceholderMetric(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Production cost',
          ),
          _PlaceholderMetric(
            icon: Icons.trending_up,
            label: 'Profit or loss',
          ),
          _PlaceholderMetric(
            icon: Icons.grass,
            label: 'Crop yield',
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final status = r['performance_status']?.toString() ?? 'N/A';
    final profit = asDouble(r['estimated_profit']) ?? 0;
    final isProfit = profit >= 0;
    final resultColor = statusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resultColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Productivity Result',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
              ),
              StatusBadge(status),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isProfit ? Icons.trending_up : Icons.trending_down,
              color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
              size: 34,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            r['performance_message']?.toString() ?? 'Evaluation complete.',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _darkGreen,
            ),
          ),

          if (r['performance_message_en'] != null) ...[
            const SizedBox(height: 5),
            Text(
              r['performance_message_en'].toString(),
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],

          const Divider(height: 30),

          _resultMetric(
            'Crop',
            r['crop_name']?.toString() ?? '-',
            Icons.grass,
          ),
          _resultMetric(
            'Harvested',
            '${r['harvested_sacks'] ?? 0} sacks',
            Icons.inventory_2_outlined,
          ),
          _resultMetric(
            'Sold',
            '${r['sold_sacks'] ?? 0} sacks',
            Icons.shopping_bag_outlined,
          ),
          _resultMetric(
            'Sales',
            peso(r['total_sales']),
            Icons.payments_outlined,
          ),
          _resultMetric(
            'Production cost',
            peso(r['production_cost']),
            Icons.account_balance_wallet_outlined,
          ),
          _resultMetric(
            isProfit ? 'Profit' : 'Loss',
            peso(profit),
            isProfit ? Icons.trending_up : Icons.trending_down,
            emphasize: true,
            valueColor: isProfit ? Colors.green.shade800 : Colors.red.shade700,
          ),

          if (r['roi_percent'] != null)
            _resultMetric(
              'Return on cost',
              '${num1(r['roi_percent'])}%',
              Icons.percent,
            ),

          if (r['yield_sacks_per_ha'] != null)
            _resultMetric(
              'Yield',
              '${num1(r['yield_sacks_per_ha'])} sacks/ha',
              Icons.agriculture_outlined,
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add another',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultMetric(
    String label,
    String value,
    IconData icon, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? const Color(0xFF34463A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderMetric({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF77917B), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7D8E80),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
