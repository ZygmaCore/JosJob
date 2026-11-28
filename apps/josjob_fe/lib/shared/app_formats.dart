class AppFormats {
  static String label(String code) =>
      code.isEmpty ? code : '${code[0].toUpperCase()}${code.substring(1)}';
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String date(DateTime value) {
    final d = value.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  static String clock(DateTime value) {
    final d = value.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String get timezone {
    final minutes = DateTime.now().timeZoneOffset.inMinutes;
    return 'UTC${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
  }

  static String dateTime(DateTime value, {bool showZone = false}) =>
      '${date(value)} · ${clock(value)}${showZone ? ' ($timezone)' : ''}';
  static String money(num amount, String currency, {int decimals = 0}) {
    final pieces = amount.toStringAsFixed(decimals).split('.');
    final whole = pieces.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${currency.toUpperCase()} $whole${pieces.length == 2 ? '.${pieces.last}' : ''}';
  }
}
