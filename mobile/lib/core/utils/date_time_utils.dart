/// Date/time helpers for the Evacuation Route Advisory app.
///
/// The backend stores timestamps as UTC-aware ISO-8601 strings.
/// All MDRRMO and resident UI should display times in Asia/Manila (UTC+8).
/// We avoid adding a timezone library by applying the +8:00 offset directly.

/// Convert a UTC [DateTime] to the Asia/Manila equivalent (UTC+8).
///
/// This is safe: DateTime.toUtc() normalises any local DateTime to UTC first,
/// then we add exactly 8 hours.
DateTime toManilaTime(DateTime utcOrLocal) {
  final utc = utcOrLocal.isUtc ? utcOrLocal : utcOrLocal.toUtc();
  return utc.add(const Duration(hours: 8));
}

/// Format a UTC timestamp as a Manila-timezone wall-clock string.
///
/// Output: "MM/DD/YYYY at HH:MM" (e.g. "04/13/2026 at 09:35")
String formatManila(DateTime utcOrLocal) {
  final manila = toManilaTime(utcOrLocal);
  final h = manila.hour.toString().padLeft(2, '0');
  final m = manila.minute.toString().padLeft(2, '0');
  return '${manila.month}/${manila.day}/${manila.year} at $h:$m';
}

/// Relative timestamp ("5m ago", "2h ago") calculated from Manila time.
String formatRelativeManila(DateTime utcOrLocal) {
  final manila = toManilaTime(utcOrLocal);
  final nowManila = toManilaTime(DateTime.now().toUtc());
  final diff = nowManila.difference(manila);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${manila.month}/${manila.day}/${manila.year}';
}
