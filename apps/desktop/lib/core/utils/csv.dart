/// Minimal RFC 4180-ish CSV encoding — no external package for something
/// this small. Quotes a field only when it needs it (contains a comma,
/// quote, or newline), doubling embedded quotes.
String buildCsv(List<String> headers, List<List<Object?>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_escapeCsvField).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_escapeCsvField).join(','));
  }
  return buffer.toString();
}

String _escapeCsvField(Object? value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}
