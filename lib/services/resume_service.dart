import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/resume_analysis_model.dart';
import '../models/job_model.dart';
import 'gemini_service.dart';
import 'job_matching_service.dart';
import 'resume_analysis_service.dart';
import 'job_service.dart';
import 'firestore_service.dart';

class ResumeService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GeminiService _geminiService;
  
  ResumeService() {
    final generativeModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
    _geminiService = GeminiService(generativeModel);
  }

  Future<String> uploadResume(String userId) async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('Keine Datei ausgewählt');
      }

      final file = File(result.files.first.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.first.name}';
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child('resumes/$userId/$fileName');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Save resume metadata to Firestore
      await _firestore.collection('resumes').doc(userId).set({
        'userId': userId,
        'fileName': result.files.first.name,
        'fileUrl': downloadUrl,
        'uploadedAt': DateTime.now().toIso8601String(),
        'fileSize': await file.length(),
      });
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Upload fehlgeschlagen: ${e.toString()}');
    }
  }

  Future<ResumeAnalysisModel> analyzeResume(String userId, String resumeUrl) async {
    try {
      print('🔄 Starte Resume-Analyse für User: $userId');
      print('📄 Resume URL: $resumeUrl');
      
      // PDF direkt analysieren (nicht Text extrahieren)
      final analysis = await _geminiService.analyzeResumeFromPdf(resumeUrl, userId);
      print('✅ PDF-Analyse abgeschlossen - Score: ${analysis.score}/100');
      
      // Jobs basierend auf Analyse finden – nur am erkannten Standort
      final jobService = JobService();
      List<JobModel> allJobs = [];
      try {
        final loc = (analysis.location.isNotEmpty && analysis.location.toLowerCase() != 'unbekannt')
            ? analysis.location
            : 'Germany'; // Fallback, wenn keine Location erkannt

        final queries = _generateJobQueries(analysis, limit: 6);
        print('🔍 SERP Queries: ${queries.join(' | ')}');

        final results = await Future.wait(
          queries.map((q) => jobService.searchJobs(query: q, location: loc)).toList(),
          eagerError: false,
        );

        // Flatten + dedupe
        final seen = <String>{};
        for (final list in results) {
          for (final j in list) {
            final key = (j.applicationUrl ?? j.title).toLowerCase();
            if (seen.add(key)) allJobs.add(j);
          }
        }
        print('💼 ${allJobs.length} Jobs in "$loc" (aggregiert)');

        // Job-Matching
        final jobMatchingService = JobMatchingService();
        final matchedJobs = jobMatchingService.matchJobsWithAnalysis(allJobs, analysis);
        print('🎯 ${matchedJobs.length} passende Jobs gematcht');
      } catch (e) {
        print('⚠️ Job-Suche übersprungen (zeige Analyse trotzdem): $e');
      }
      
      // In Firestore speichern
      await _firestore.collection('resume_analyses').doc(userId).set(analysis.toMap());
      print('💾 Analyse in Firestore gespeichert');
      
      return analysis;
    } catch (e) {
      print('❌ Analyse-Fehler: $e');
      throw Exception('Analyse fehlgeschlagen: ${e.toString()}');
    }
  }

  String _generateJobQuery(ResumeAnalysisModel analysis) {
    // Behalte eine kurze Basisquery für Einzelaufrufe (Kompatibilität)
    final topSkills = analysis.skills.take(3).join(' ');
    final experience = analysis.experienceLevel;

    String query = topSkills;

    switch (experience) {
      case 'entry':
        query += ' junior';
        break;
      case 'mid':
        query += ' mid level';
        break;
      case 'senior':
        query += ' senior';
        break;
      case 'expert':
        query += ' lead principal';
        break;
    }

    print('🔍 Job-Query generiert: $query');
    return query;
  }

  List<String> _generateJobQueries(ResumeAnalysisModel a, {int limit = 6}) {
    final skills = a.skills.take(5).toList();
    final titles = <String>{};

    for (final s in skills) {
      final l = s.toLowerCase();
      if (l.contains('data')) { titles.add('data analyst'); titles.add('business intelligence'); }
      if (l.contains('sql')) { titles.add('data engineer'); }
      if (l.contains('python')) { titles.add('python developer'); }
      if (l.contains('system')) { titles.add('system analyst'); }
      if (l.contains('consult')) { titles.add('consultant'); }
      titles.add(s);
    }

    switch (a.experienceLevel) {
      case 'entry': titles.add('junior'); break;
      case 'mid': titles.add('mid level'); break;
      case 'senior': titles.add('senior'); break;
      case 'expert': titles.add('lead'); titles.add('principal'); break;
    }

    final base = <String>{};
    for (final t in titles) {
      if (t.trim().isEmpty) continue;
      base.add(t.trim());
    }

    return base.take(limit).toList();
  }

  Future<String> _extractTextFromResume(String resumeUrl) async {
    try {
      // For now, return a placeholder text
      // In a real implementation, you would download the file and extract text
      // This is a simplified version
      return '''
Max Mustermann
Softwareentwickler

Erfahrung:
- 3 Jahre als Full-Stack Entwickler
- Spezialisiert auf React, Node.js, Python
- Erfahrung mit Cloud-Services (AWS, Azure)

Bildung:
- Bachelor Informatik, TU München (2018-2022)
- Zertifikat: AWS Solutions Architect

Fähigkeiten:
- Programmiersprachen: JavaScript, Python, Java, C#
- Frameworks: React, Angular, Vue.js, Express.js
- Datenbanken: MySQL, PostgreSQL, MongoDB
- Cloud: AWS, Azure, Docker, Kubernetes

Projekte:
- E-Commerce Plattform (React, Node.js, MongoDB)
- Mobile App (Flutter, Firebase)
- Microservices Architektur (Docker, Kubernetes)
''';
    } catch (e) {
      throw Exception('Text-Extraktion fehlgeschlagen: ${e.toString()}');
    }
  }

  Future<ResumeAnalysisModel?> getResumeAnalysis(String userId) async {
    try {
      final doc = await _firestore.collection('resume_analyses').doc(userId).get();
      if (doc.exists) {
        return ResumeAnalysisModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteResume(String userId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('resumes').doc(userId).delete();
      await _firestore.collection('resume_analyses').doc(userId).delete();
      
      // Delete from Storage
      final ref = _storage.ref().child('resumes/$userId');
      final listResult = await ref.listAll();
      
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      throw Exception('Löschen fehlgeschlagen: ${e.toString()}');
    }
  }

  Future<bool> hasResume(String userId) async {
    try {
      final doc = await _firestore.collection('resumes').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get latest resume text
  Future<String> getLatestResumeText() async {
    try {
      // This is a simplified implementation
      // In a real app, you would extract text from the latest uploaded resume
      return '''
Max Mustermann
Softwareentwickler

Erfahrung:
- 3 Jahre als Full-Stack Entwickler
- Spezialisiert auf React, Node.js, Python
- Erfahrung mit Cloud-Services (AWS, Azure)

Bildung:
- Bachelor Informatik, TU München (2018-2022)
- Zertifikat: AWS Solutions Architect

Fähigkeiten:
- Programmiersprachen: JavaScript, Python, Java, C#
- Frameworks: React, Angular, Vue.js, Express.js
- Datenbanken: MySQL, PostgreSQL, MongoDB
- Cloud: AWS, Azure, Docker, Kubernetes

Projekte:
- E-Commerce Plattform (React, Node.js, MongoDB)
- Mobile App (Flutter, Firebase)
- Microservices Architektur (Docker, Kubernetes)
''';
    } catch (e) {
      throw Exception('Resume-Text konnte nicht geladen werden: ${e.toString()}');
    }
  }

  // Get latest analysis
  Future<ResumeAnalysisModel?> getLatestAnalysis() async {
    try {
      final snapshot = await _firestore
          .collection('resume_analyses')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return ResumeAnalysisModel.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
