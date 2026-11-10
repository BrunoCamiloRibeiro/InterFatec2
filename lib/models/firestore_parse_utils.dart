/// Utilitário puro para desserialização resiliente de datas vindas do Firestore.
///
/// Suporta instâncias de [DateTime], `Timestamp` do Cloud Firestore (via `.toDate()`),
/// mapas JSON `{seconds, nanoseconds}`, timestamps numéricos (em ms ou s) e strings ISO-8601.
DateTime? parsearDataFirestore(dynamic valor, {bool emUtc = false}) {
  if (valor == null) return null;
  if (valor is DateTime) return emUtc ? valor.toUtc() : valor;

  try {
    final dt = (valor as dynamic).toDate();
    if (dt is DateTime) return emUtc ? dt.toUtc() : dt;
  } catch (_) {}

  if (valor is Map) {
    final sec = valor['seconds'] ?? valor['_seconds'];
    if (sec is num) {
      final nanosec = valor['nanoseconds'] ?? valor['_nanoseconds'] ?? 0;
      final msExtra = (nanosec is num) ? (nanosec ~/ 1000000) : 0;
      final dtUtc = DateTime.fromMillisecondsSinceEpoch(
        sec.toInt() * 1000 + msExtra,
        isUtc: true,
      );
      return emUtc ? dtUtc : dtUtc.toLocal();
    }
  }

  if (valor is num) {
    final ms = valor > 10000000000 ? valor.toInt() : (valor * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: emUtc);
  }

  final parsed = DateTime.tryParse(valor.toString());
  if (parsed != null) return emUtc ? parsed.toUtc() : parsed;
  return null;
}
