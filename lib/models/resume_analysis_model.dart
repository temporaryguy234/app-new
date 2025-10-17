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
  final String? postalCode;
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
    this.postalCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ResumeAnalysisModel.fromMap(Map<String, dynamic> map) {
    return ResumeAnalysisModel(
      id: (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      userId: (map['userId'] ?? '').toString(),
      resumeUrl: (map['resumeUrl'] ?? '').toString(),
      score: _toDouble(map['score']) ?? 0.0,
      strengths: _toStringList(map['strengths']),
      improvements: _toStringList(map['improvements']),
      skills: _toStringList(map['skills']),
      yearsOfExperience: _toInt(map['yearsOfExperience']) ?? 0,
      experienceLevel: (map['experienceLevel'] ?? 'entry').toString(),
      industries: _toStringList(map['industries']),
      summary: (map['summary'] ?? '').toString(),
      location: (map['location'] ?? 'Unbekannt').toString(),
      postalCode: (map['postalCode'] ?? map['zip'] ?? '').toString().trim().isEmpty
          ? null
          : (map['postalCode'] ?? map['zip']).toString(),
      createdAt: _toDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(map['updatedAt']) ?? DateTime.now(),
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
      if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ---- Safe parsing helpers (UI resilience) ----
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _toDate(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<String> _toStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (v is String) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
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
