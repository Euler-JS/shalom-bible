import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime date, {String locale = 'pt_BR'}) {
    return DateFormat('dd/MM/yyyy', locale).format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Hoje';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatRelativeEN(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MM/dd/yyyy').format(date);
  }
}
