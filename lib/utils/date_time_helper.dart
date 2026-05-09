class DateTimeHelper {
  static String format(DateTime dt) {
    final date = "${dt.day}/${dt.month}/${dt.year}";
    final time =
        "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}";

    return "$date • $time";
  }
}