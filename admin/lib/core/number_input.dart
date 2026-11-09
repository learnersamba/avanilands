import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _indianGrouping = NumberFormat('#,##,##0', 'en_IN');

/// Formats whole rupees as you type: 4500000 → 45,00,000.
class IndianNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 13 ? digits.substring(0, 13) : digits;
    final text = _indianGrouping.format(int.parse(trimmed));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Allows a decimal number with up to [decimals] places: "25", "2.5", "0.125".
class DecimalFormatter extends TextInputFormatter {
  DecimalFormatter({this.decimals = 3});

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final ok = RegExp('^\\d{0,9}(\\.\\d{0,$decimals})?\$')
        .hasMatch(newValue.text);
    return ok ? newValue : oldValue;
  }
}

/// "45,00,000" → 4500000; empty → null.
double? parseNumber(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String formatInputNumber(double? value, {bool rupees = false}) {
  if (value == null) return '';
  if (rupees) return _indianGrouping.format(value.round());
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

/// ₹45 L / ₹1.2 Cr / ₹85,000 — the short form used on cards.
String shortRupees(double value) {
  if (value >= 10000000) return '₹${_trim(value / 10000000)} Cr';
  if (value >= 100000) return '₹${_trim(value / 100000)} L';
  return '₹${_indianGrouping.format(value.round())}';
}

String _trim(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceAll(RegExp(r'\.?0+$'), '');
}
