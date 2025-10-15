import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resume_analysis_model.dart';
import '../models/job_model.dart';
import 'gemini_service.dart';
import 'job_service.dart';
import 'job_matching_service.dart';
import 'firestore_service.dart';

class ResumeAnalysisService {
  final GeminiService _geminiService;
  final JobService _jobService;
  final JobMatchingService _jobMatchingService;
  final FirestoreService _firestoreService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  ResumeAnalysisService({
    required GeminiService geminiService,
    required JobService jobService,
    required JobMatchingService jobMatchingService,
    required FirestoreService firestoreService,
  }) : _geminiService = geminiService,
       _jobService = jobService,
       _jobMatchingService = jobMatchingService,
       _firestoreService = firestoreService;
  
  Future<ResumeAnalysisResult> analyzeAndMatchJobs(
    String userId,
    String resumeText,
    String resumeUrl,
  ) async {
    try {
      print('🔍 Starte Lebenslauf-Analyse für User: $userId');
      
      // 1. Gemini-Analyse
      print('📝 Analysiere Lebenslauf mit Gemini...');
      final analysis = await _geminiService.analyzeResume(resumeText, userId, resumeUrl);
      print('✅ Analyse abgeschlossen - Score: ${analysis.score}/100');
      
      // 2. Jobs laden
      print('💼 Lade verfügbare Jobs...');
      final allJobs = await _jobService.searchJobs(
        query: _generateJobQuery(analysis),
        location: 'Deutschland',
      );
      print('📋 ${allJobs.length} Jobs gefunden');
      
      // 3. Job-Matching
      print('🎯 Führe Job-Matching durch...');
      final matchedJobs = _jobMatchingService.matchJobsWithAnalysis(allJobs, analysis);
      print('✅ ${matchedJobs.length} passende Jobs gefunden');
      
      // 4. In Firestore speichern
      print('💾 Speichere Analyse in Firestore...');
      await _firestore.collection('resume_analyses').doc(userId).set(analysis.toMap());
      print('✅ Analyse gespeichert');
      
      // 5. Ergebnis zurückgeben
      final result = ResumeAnalysisResult(
        analysis: analysis,
        matchedJobs: matchedJobs,
        totalJobsFound: allJobs.length,
        matchedJobsCount: matchedJobs.length,
      );
      
      print('🎉 Analyse-Workflow erfolgreich abgeschlossen!');
      return result;
      
    } catch (e) {
      print('❌ Fehler bei der Analyse: $e');
      throw Exception('Lebenslauf-Analyse fehlgeschlagen: ${e.toString()}');
    }
  }
  
  String _generateJobQuery(ResumeAnalysisModel analysis) {
    // Erstelle Suchquery basierend auf Skills und Industries
    final skills = analysis.skills.take(3).join(' ');
    final industries = analysis.industries.take(2).join(' ');
    return '$skills $industries Entwickler';
  }
}

class ResumeAnalysisResult {
  final ResumeAnalysisModel analysis;
  final List<JobModel> matchedJobs;
  final int totalJobsFound;
  final int matchedJobsCount;
  
  ResumeAnalysisResult({
    required this.analysis,
    required this.matchedJobs,
    required this.totalJobsFound,
    required this.matchedJobsCount,
  });
}
