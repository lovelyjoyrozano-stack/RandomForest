import 'package:flutter/material.dart';

import '../core/farm_store.dart';
import '../core/theme.dart';
import '../models/models.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorBanner(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2BE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: statusBad),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const MetricRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
}

/// Dropdown for the selected farm; used at the top of feature screens.
class FarmSelectorBar extends StatelessWidget {
  final FarmStore store;
  final void Function(Farm farm)? onChanged;
  const FarmSelectorBar({super.key, required this.store, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = store.selected;
    if (store.farms.isEmpty || selected == null) return const SizedBox.shrink();

    return DropdownButtonFormField<int>(
      key: ValueKey(selected.id),
      initialValue: selected.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Farm',
        prefixIcon: Icon(Icons.agriculture),
      ),
      items: [
        for (final f in store.farms)
          DropdownMenuItem<int>(
              value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (id) {
        if (id == null) return;
        final farm = store.farms.firstWhere((f) => f.id == id);
        store.select(farm);
        onChanged?.call(farm);
      },
    );
  }
}

class NoFarmNotice extends StatelessWidget {
  final VoidCallback onAdd;
  const NoFarmNotice({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.add_location_alt_outlined,
                size: 44, color: primaryGreen),
            const SizedBox(height: 12),
            const Text('Register your farm first',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Add a farm (with its area in hectares) to get weather advice, '
              'record harvests and see yield forecasts.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAdd, child: const Text('Add Farm')),
          ],
        ),
      ),
    );
  }
}

IconData weatherIcon(String? main) {
  switch ((main ?? '').toLowerCase()) {
    case 'clear':        return Icons.wb_sunny;
    case 'clouds':       return Icons.cloud;
    case 'rain':         return Icons.umbrella;
    case 'drizzle':      return Icons.grain;
    case 'thunderstorm': return Icons.thunderstorm;
    case 'snow':         return Icons.ac_unit;
    case 'mist':
    case 'fog':
    case 'haze':
    case 'smoke':
    case 'dust':
    case 'sand':
    case 'ash':          return Icons.foggy;
    case 'squall':
    case 'tornado':      return Icons.air;
    default:             return Icons.wb_cloudy_outlined;
  }
}

Color weatherColor(String? main) {
  switch ((main ?? '').toLowerCase()) {
    case 'clear':        return const Color(0xFFF59E0B);
    case 'rain':
    case 'drizzle':      return const Color(0xFF1E88E5);
    case 'thunderstorm':
    case 'squall':
    case 'tornado':      return const Color(0xFF6A1B9A);
    case 'clouds':       return const Color(0xFF607D8B);
    default:             return primaryGreen;
  }
}

String capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
