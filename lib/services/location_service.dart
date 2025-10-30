class LocationService {
  static String fold(String s) => s
      .toLowerCase()
      .replaceAll('ae', 'ä')
      .replaceAll('oe', 'ö')
      .replaceAll('ue', 'ü')
      .replaceAll('ss', 'ß')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a');

  static Iterable<String> suggestCities(String query, List<String> base) {
    final q = fold(query.trim());
    if (q.isEmpty) return const Iterable<String>.empty();
    return base.where((c) => fold(c).startsWith(q)).take(8);
  }
}

