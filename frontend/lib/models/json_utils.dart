/// Tolerant JSON parsing helpers : the API returns numbers as numbers,
/// but a string ("12.50") must not crash the app either.
class JsonUtils {
  JsonUtils._();

  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Accepts 'YYYY-MM-DD' (DATE columns) and ISO 8601 timestamps.
  /// A 'YYYY-MM-DD' date is parsed as a local date, without timezone shift.
  static DateTime? toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// DateTime -> 'YYYY-MM-DD', the format expected by the API for DATE fields.
  static String? formatDate(DateTime? date) {
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }
}
