import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_model.dart';
import 'resume_analysis_model.dart';

class JobCacheModel {
  final String userId;
  final ResumeAnalysisModel? analysis;
  final DateTime? lastAnalysisAt;
  final String? analysisHash;
  final DateTime? lastSearchAt;
  final List<JobModel> jobs;
  final DateTime? lastVerifiedAt;
  final Map<String, bool> jobOnlineStatus; // jobId -> isOnline

  JobCacheModel({
    required this.userId,
    this.analysis,
    this.lastAnalysisAt,
    this.analysisHash,
    this.lastSearchAt,
    required this.jobs,
    this.lastVerifiedAt,
    this.jobOnlineStatus = const {},
  });

  factory JobCacheModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobCacheModel(
      userId: doc.id,
      analysis: data['analysis'] != null 
        ? ResumeAnalysisModel.fromMap(data['analysis']) 
        : null,
      lastAnalysisAt: data['lastAnalysisAt']?.toDate(),
      analysisHash: data['analysisHash'],
      lastSearchAt: data['lastSearchAt']?.toDate(),
      jobs: (data['jobs'] as List<dynamic>?)
        ?.map((j) => JobModel.fromMap(j))
        .toList() ?? [],
      lastVerifiedAt: data['lastVerifiedAt']?.toDate(),
      jobOnlineStatus: Map<String, bool>.from(data['jobOnlineStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'analysis': analysis?.toMap(),
      'lastAnalysisAt': lastAnalysisAt,
      'analysisHash': analysisHash,
      'lastSearchAt': lastSearchAt,
      'jobs': jobs.map((j) => j.toMap()).toList(),
      'lastVerifiedAt': lastVerifiedAt,
      'jobOnlineStatus': jobOnlineStatus,
    };
  }

  JobCacheModel copyWith({
    ResumeAnalysisModel? analysis,
    DateTime? lastAnalysisAt,
    String? analysisHash,
    DateTime? lastSearchAt,
    List<JobModel>? jobs,
    DateTime? lastVerifiedAt,
    Map<String, bool>? jobOnlineStatus,
  }) {
    return JobCacheModel(
      userId: userId,
      analysis: analysis ?? this.analysis,
      lastAnalysisAt: lastAnalysisAt ?? this.lastAnalysisAt,
      analysisHash: analysisHash ?? this.analysisHash,
      lastSearchAt: lastSearchAt ?? this.lastSearchAt,
      jobs: jobs ?? this.jobs,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      jobOnlineStatus: jobOnlineStatus ?? this.jobOnlineStatus,
    );
  }

  // TTL checks
  bool get isAnalysisFresh => 
    lastAnalysisAt != null && 
    DateTime.now().difference(lastAnalysisAt!).inDays < 7;

  bool get isSearchFresh => 
    lastSearchAt != null && 
    DateTime.now().difference(lastSearchAt!).inHours < 24;

  bool get isVerificationFresh => 
    lastVerifiedAt != null && 
    DateTime.now().difference(lastVerifiedAt!).inHours < 12;

  bool get isSearchStale => 
    lastSearchAt != null && 
    DateTime.now().difference(lastSearchAt!).inDays >= 3;
}
