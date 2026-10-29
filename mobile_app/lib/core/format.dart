double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 12345.5 -> "₱12,345.50"; negatives -> "-₱1,000.00".
String peso(dynamic value) {
  final n = asDouble(value) ?? 0;
  final fixed = n.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  return '${n < 0 ? '-' : ''}₱${_group(parts[0])}.${parts[1]}';
}

String num1(dynamic value, [int digits = 1]) =>
    (asDouble(value) ?? 0).toStringAsFixed(digits);

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
