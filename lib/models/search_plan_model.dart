import 'dart:convert';

class SearchPlan {
  final String city;                 // z. B. "Aschaffenburg"
  final String countryEnglish;       // z. B. "Germany"
  final String serpLocation;         // z. B. "Aschaffenburg, Germany"
  final List<String> queries;        // 1-3 Queries: ("titel1" OR "titel2") in CITY
  final List<String> titles;         // alle Titel aus den Queries (DE)
  final List<String> jobTypes;       // Vorschläge: Werkstudent, Praktikum, Teilzeit, Vollzeit, Minijob, ...

  const SearchPlan({
    required this.city,
    required this.countryEnglish,
    required this.serpLocation,
    required this.queries,
    required this.titles,
    required this.jobTypes,
  });

  factory SearchPlan.empty() => const SearchPlan(
        city: '',
        countryEnglish: '',
        serpLocation: '',
        queries: [],
        titles: [],
        jobTypes: [],
      );

  Map<String, dynamic> toMap() => {
        'city': city,
        'countryEnglish': countryEnglish,
        'serpLocation': serpLocation,
        'queries': queries,
        'titles': titles,
        'jobTypes': jobTypes,
      };

  factory SearchPlan.fromMap(Map<String, dynamic> map) {
    List<String> _asStrings(dynamic v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      if (v is String) return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      return const [];
    }

    return SearchPlan(
      city: (map['city'] ?? '').toString(),
      countryEnglish: (map['countryEnglish'] ?? '').toString(),
      serpLocation: (map['serpLocation'] ?? map['location'] ?? '').toString(),
      queries: _asStrings(map['queries']),
      titles: _asStrings(map['titles']),
      jobTypes: _asStrings(map['jobTypes']),
    );
  }

  static SearchPlan fromJson(String jsonStr) {
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return SearchPlan.fromMap(map);
    } catch (_) {
      return SearchPlan.empty();
    }
  }
}

