import 'package:intl/intl.dart';

/// Formatação de números e datas no padrão brasileiro.
abstract final class Fmt {
  static final _time = DateFormat('HH:mm', 'pt_BR');
  static final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dayMonth = DateFormat('dd/MM', 'pt_BR');
  static final _dateTime = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

  static String number(num? value, {int decimals = 1}) {
    if (value == null) return '—';
    return NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: decimals)
        .format(value);
  }

  /// Casas decimais adequadas para cada unidade.
  static int decimalsFor(String unit) => switch (unit) {
        'bar' || 'm/s' || '%obs/m' => 2,
        '%' || 'alertas' => 0,
        _ => 1,
      };

  static String measure(num? value, String unit) {
    if (value == null) return '—';
    return '${number(value, decimals: decimalsFor(unit))} $unit';
  }

  static String percent(num value) => '${number(value, decimals: 0)}%';

  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  static String time(DateTime d) => _time.format(d.toLocal());
  static String date(DateTime d) => _date.format(d.toLocal());
  static String dayMonth(DateTime d) => _dayMonth.format(d.toLocal());
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  /// "Hoje, 10:24", "Ontem, 18:00" ou "05/10/2026, 09:12".
  static String relativeDay(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final today = DateTime(ref.year, ref.month, ref.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje, ${time(local)}';
    if (diff == 1) return 'Ontem, ${time(local)}';
    return '${date(local)}, ${time(local)}';
  }

  /// "agora", "há 5 min", "há 3 h", "há 2 dias".
  static String ago(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return diff.inDays == 1 ? 'há 1 dia' : 'há ${diff.inDays} dias';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Primeiro e segundo nome, para saudações.
  static String shortName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 2) return parts.join(' ');
    return '${parts[0]} ${parts[1]}';
  }
}
