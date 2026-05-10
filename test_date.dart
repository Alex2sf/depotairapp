import 'package:intl/intl.dart';

void main() {
  var utcStr = "2026-03-02T13:00:00.000000Z";
  var dt = DateTime.parse(utcStr);
  print("Parsed (isUtc: ${dt.isUtc}): $dt");
  
  var formatted = DateFormat('dd MMM yyyy, HH:mm').format(dt);
  print("Formatted: $formatted");
  
  var formattedLocal = DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
  print("Formatted Local: $formattedLocal");
}
