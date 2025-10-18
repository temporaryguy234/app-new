import 'package:cloud_firestore/cloud_firestore.dart';

class ResumeAnalysisModel {
  final String id;
  final String userId;
  final String resumeUrl;
  final double score;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> skills;
  final int yearsOfExperience;
  final String experienceLevel;
  final List<String> industries;
  final String summary;
  final String location;
  final String postalCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResumeAnalysisModel({
    required this.id,
    required this.userId,
    required this.resumeUrl,
    required this.score,
    required this.strengths,
    required this.improvements,
    required this.skills,
    required this.yearsOfExperience,
    required this.experienceLevel,
    required this.industries,
    required this.summary,
    required this.location,
    required this.postalCode,
    required this.createdAt,
    required this.updatedAt,
  });

  ResumeAnalysisModel copyWith({
    String? postalCode,
  }) {
    return ResumeAnalysisModel(
      id: id,
      userId: userId,
      resumeUrl: resumeUrl,
      score: score,
      strengths: strengths,
      improvements: improvements,
      skills: skills,
      yearsOfExperience: yearsOfExperience,
      experienceLevel: experienceLevel,
      industries: industries,
      summary: summary,
      location: location,
      postalCode: postalCode ?? this.postalCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ResumeAnalysisModel.fromMap(Map<String, dynamic> map) {
    return ResumeAnalysisModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      resumeUrl: map['resumeUrl'] as String,
      score: (map['score'] as num).toDouble(),
      strengths: List<String>.from(map['strengths'] ?? []),
      improvements: List<String>.from(map['improvements'] ?? []),
      skills: List<String>.from(map['skills'] ?? []),
      yearsOfExperience: map['yearsOfExperience'] as int,
      experienceLevel: map['experienceLevel'] as String,
      industries: List<String>.from(map['industries'] ?? []),
      summary: map['summary'] as String,
      location: map['location'] as String? ?? 'Unbekannt',
      postalCode: map['postalCode'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'resumeUrl': resumeUrl,
      'score': score,
      'strengths': strengths,
      'improvements': improvements,
      'skills': skills,
      'yearsOfExperience': yearsOfExperience,
      'experienceLevel': experienceLevel,
      'industries': industries,
      'summary': summary,
      'location': location,
      'postalCode': postalCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get scoreText {
    if (score >= 90) return 'Exzellent';
    if (score >= 80) return 'Sehr gut';
    if (score >= 70) return 'Gut';
    if (score >= 60) return 'Befriedigend';
    return 'Verbesserungsbedarf';
  }

  String get experienceText {
    switch (experienceLevel.toLowerCase()) {
      case 'entry':
        return 'Einsteiger (0-2 Jahre)';
      case 'mid':
        return 'Erfahren (3-5 Jahre)';
      case 'senior':
        return 'Senior (6-10 Jahre)';
      case 'expert':
        return 'Experte (10+ Jahre)';
      default:
        return 'Unbekannt';
    }
  }

  List<String> get topSkills {
    return skills.take(5).toList();
  }

  String get formattedScore {
    return '${score.toStringAsFixed(1)}/100';
  }

  bool get isHighScore {
    return score >= 80;
  }

  bool get needsImprovement {
    return score < 70;
  }
}
