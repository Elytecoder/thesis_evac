/// Compare barangay strings regardless of spacing/case (matches backend normalization).
class BarangayNormalize {
  BarangayNormalize._();

  static String comparisonKey(String? raw) {
    if (raw == null) return '';
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool matches(String? a, String? b) => comparisonKey(a) == comparisonKey(b);
}
