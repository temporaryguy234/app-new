class FilterModel {
  final String? location;
  final double? maxDistance; // in km
  final double? minSalary;
  final double? maxSalary;
  final List<String> jobTypes; // Vollzeit, Teilzeit, Praktikum, etc.
  final double? minRemotePercentage;
  final List<String> industries;
  final List<String> experienceLevels; // Entry, Mid, Senior
  final List<String> contractTypes; // Festanstellung, Befristet, Freelance
  final List<String>? technologies;
  final List<String>? companySizes;
  final List<String>? benefits;
  // New advanced filters
  final int? publishedWithinDays; // 1,3,7,14; null = any
  final List<String>? workSchedules; // Vollzeit, Teilzeit, Schicht
  final List<String>? languages; // Deutsch, Englisch
  final bool? onlyWithSalary; // nur Angebote mit Gehaltsangabe

  FilterModel({
    this.location,
    this.maxDistance,
    this.minSalary,
    this.maxSalary,
    this.jobTypes = const [],
    this.minRemotePercentage,
    this.industries = const [],
    this.experienceLevels = const [],
    this.contractTypes = const [],
    this.technologies,
    this.companySizes,
    this.benefits,
    this.publishedWithinDays,
    this.workSchedules,
    this.languages,
    this.onlyWithSalary,
  });

  factory FilterModel.fromMap(Map<String, dynamic> map) {
    return FilterModel(
      location: map['location'],
      maxDistance: map['maxDistance']?.toDouble(),
      minSalary: map['minSalary']?.toDouble(),
      maxSalary: map['maxSalary']?.toDouble(),
      jobTypes: List<String>.from(map['jobTypes'] ?? []),
      minRemotePercentage: map['minRemotePercentage']?.toDouble(),
      industries: List<String>.from(map['industries'] ?? []),
      experienceLevels: List<String>.from(map['experienceLevels'] ?? []),
      contractTypes: List<String>.from(map['contractTypes'] ?? []),
      technologies: map['technologies'] != null ? List<String>.from(map['technologies']) : null,
      companySizes: map['companySizes'] != null ? List<String>.from(map['companySizes']) : null,
      benefits: map['benefits'] != null ? List<String>.from(map['benefits']) : null,
      publishedWithinDays: map['publishedWithinDays'],
      workSchedules: map['workSchedules'] != null ? List<String>.from(map['workSchedules']) : null,
      languages: map['languages'] != null ? List<String>.from(map['languages']) : null,
      onlyWithSalary: map['onlyWithSalary'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'maxDistance': maxDistance,
      'minSalary': minSalary,
      'maxSalary': maxSalary,
      'jobTypes': jobTypes,
      'minRemotePercentage': minRemotePercentage,
      'industries': industries,
      'experienceLevels': experienceLevels,
      'contractTypes': contractTypes,
      'technologies': technologies,
      'companySizes': companySizes,
      'benefits': benefits,
      'publishedWithinDays': publishedWithinDays,
      'workSchedules': workSchedules,
      'languages': languages,
      'onlyWithSalary': onlyWithSalary,
    };
  }

  FilterModel copyWith({
    String? location,
    double? maxDistance,
    double? minSalary,
    double? maxSalary,
    List<String>? jobTypes,
    double? minRemotePercentage,
    List<String>? industries,
    List<String>? experienceLevels,
    List<String>? contractTypes,
    List<String>? technologies,
    List<String>? companySizes,
    List<String>? benefits,
    int? publishedWithinDays,
    List<String>? workSchedules,
    List<String>? languages,
    bool? onlyWithSalary,
  }) {
    return FilterModel(
      location: location ?? this.location,
      maxDistance: maxDistance ?? this.maxDistance,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      jobTypes: jobTypes ?? this.jobTypes,
      minRemotePercentage: minRemotePercentage ?? this.minRemotePercentage,
      industries: industries ?? this.industries,
      experienceLevels: experienceLevels ?? this.experienceLevels,
      contractTypes: contractTypes ?? this.contractTypes,
      technologies: technologies ?? this.technologies,
      companySizes: companySizes ?? this.companySizes,
      benefits: benefits ?? this.benefits,
      publishedWithinDays: publishedWithinDays ?? this.publishedWithinDays,
      workSchedules: workSchedules ?? this.workSchedules,
      languages: languages ?? this.languages,
      onlyWithSalary: onlyWithSalary ?? this.onlyWithSalary,
    );
  }

  bool get hasActiveFilters {
    return location != null ||
        maxDistance != null ||
        minSalary != null ||
        maxSalary != null ||
        jobTypes.isNotEmpty ||
        minRemotePercentage != null ||
        industries.isNotEmpty ||
        experienceLevels.isNotEmpty ||
        contractTypes.isNotEmpty ||
        (technologies?.isNotEmpty ?? false) ||
        (companySizes?.isNotEmpty ?? false) ||
        (benefits?.isNotEmpty ?? false) ||
        publishedWithinDays != null ||
        (workSchedules?.isNotEmpty ?? false) ||
        (languages?.isNotEmpty ?? false) ||
        (onlyWithSalary == true);
  }

  int get activeFilterCount {
    int count = 0;
    if (location != null) count++;
    if (maxDistance != null) count++;
    if (minSalary != null || maxSalary != null) count++;
    if (jobTypes.isNotEmpty) count++;
    if (minRemotePercentage != null) count++;
    if (industries.isNotEmpty) count++;
    if (experienceLevels.isNotEmpty) count++;
    if (contractTypes.isNotEmpty) count++;
    if (technologies?.isNotEmpty ?? false) count++;
    if (companySizes?.isNotEmpty ?? false) count++;
    if (benefits?.isNotEmpty ?? false) count++;
    if (publishedWithinDays != null) count++;
    if (workSchedules?.isNotEmpty ?? false) count++;
    if (languages?.isNotEmpty ?? false) count++;
    if (onlyWithSalary == true) count++;
    return count;
  }
}
