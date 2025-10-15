class JobModel {
  final String id;
  final String title;
  final String company;
  final String? companyLogo;
  final String location;
  final String? salary;
  final String? description;
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

  JobModel({
    required this.id,
    required this.title,
    required this.company,
    this.companyLogo,
    required this.location,
    this.salary,
    this.description,
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
