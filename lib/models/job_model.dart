class JobModel {
  final String id;
  final String title;
  final String company;
  final String? companyLogo;
  final String location;
  final String? salary;
  final String? description;
  final String? sourceId; // SerpAPI job_id (compat)
  final String? sourceUrl; // URL for verification
  final List<String> tags;
  final String? remotePercentage;
  final String jobType; // Vollzeit, Teilzeit, Praktikum, etc.
  final String? experienceLevel;
  final String? applicationUrl;
  final DateTime postedAt;
  final int? applicantCount;
  final double? distance; // in km
  final List<String> skills;
  final List<String> industries;
  // Zusätzliche, detailliertere Felder
  final List<String> requirements;
  final List<String> responsibilities;
  final List<String> benefits;
  final String companySize;
  final String workType; // schedule_type o.ä.
  final String industry; // primäre Branche
  final String companyDescription;

  JobModel({
    required this.id,
    required this.title,
    required this.company,
    this.companyLogo,
    required this.location,
    this.salary,
    this.description,
    this.sourceId,
    this.sourceUrl,
    this.tags = const [],
    this.remotePercentage,
    required this.jobType,
    this.experienceLevel,
    this.applicationUrl,
    required this.postedAt,
    this.applicantCount,
    this.distance,
    this.skills = const [],
    this.industries = const [],
    this.requirements = const [],
    this.responsibilities = const [],
    this.benefits = const [],
    this.companySize = '',
    this.workType = '',
    this.industry = '',
    this.companyDescription = '',
  });

  factory JobModel.fromMap(Map<String, dynamic> map) {
    return JobModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      company: map['company'] ?? '',
      companyLogo: map['companyLogo'],
      location: map['location'] ?? '',
      salary: map['salary'],
      description: map['description'],
      sourceId: map['sourceId'],
      sourceUrl: map['sourceUrl'],
      tags: List<String>.from(map['tags'] ?? []),
      remotePercentage: map['remotePercentage'],
      jobType: map['jobType'] ?? '',
      experienceLevel: map['experienceLevel'],
      applicationUrl: map['applicationUrl'],
      postedAt: DateTime.parse(map['postedAt']),
      applicantCount: map['applicantCount'],
      distance: map['distance']?.toDouble(),
      skills: List<String>.from(map['skills'] ?? []),
      industries: List<String>.from(map['industries'] ?? []),
      requirements: List<String>.from(map['requirements'] ?? []),
      responsibilities: List<String>.from(map['responsibilities'] ?? []),
      benefits: List<String>.from(map['benefits'] ?? []),
      companySize: map['companySize'] ?? '',
      workType: map['workType'] ?? '',
      industry: map['industry'] ?? '',
      companyDescription: map['companyDescription'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'companyLogo': companyLogo,
      'location': location,
      'salary': salary,
      'description': description,
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
      'tags': tags,
      'remotePercentage': remotePercentage,
      'jobType': jobType,
      'experienceLevel': experienceLevel,
      'applicationUrl': applicationUrl,
      'postedAt': postedAt.toIso8601String(),
      'applicantCount': applicantCount,
      'distance': distance,
      'skills': skills,
      'industries': industries,
      'requirements': requirements,
      'responsibilities': responsibilities,
      'benefits': benefits,
      'companySize': companySize,
      'workType': workType,
      'industry': industry,
      'companyDescription': companyDescription,
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(postedAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} Tag${difference.inDays > 1 ? 'e' : ''} her';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} Stunde${difference.inHours > 1 ? 'n' : ''} her';
    } else {
      return 'Gerade eben';
    }
  }

  String get applicantText {
    if (applicantCount == null) return '';
    return '$applicantCount Bewerber';
  }
}
