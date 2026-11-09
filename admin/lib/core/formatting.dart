import 'package:intl/intl.dart';

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _dateTime = DateFormat('d MMM y, h:mm a');
final _date = DateFormat('d MMM y');

/// ₹36,00,000 (Indian grouping).
String formatRupees(num value) => _rupees.format(value);

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

String formatDate(DateTime value) => _date.format(value.toLocal());

/// "just now", "5 min ago", "3 h ago", "yesterday", else the date.
String formatRelative(DateTime value, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(value);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays == 1) return 'yesterday';
  return formatDate(value);
}

/// "follow_up" → "Follow up".
String humanize(String value) {
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
