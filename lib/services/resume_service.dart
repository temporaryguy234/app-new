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
      
      // KEINE Jobsuche hier - nur Analyse speichern
      await _firestore.collection('resume_analyses').doc(userId).set(analysis.toMap());
      print('💾 Analyse in Firestore gespeichert');
      
      return analysis; // Früh zurückgeben
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

  // Intelligente Jobtitel-Ableitung basierend auf Skills + Erfahrung
  String _buildSmartJobQuery(ResumeAnalysisModel a) {
    final titles = <String>{};

    // Kompakte, echte Titel (DE+EN)
    for (final s in a.skills) {
      final t = s.toLowerCase();
      if (t.contains('data') || t.contains('analys')) {
        titles.addAll({'data analyst','business analyst','datenanalyst','geschäftsanalyst'});
      }
      if (t.contains('sql') || t.contains('datenbank')) {
        titles.addAll({'data engineer','datenbankentwickler','sql entwickler'});
      }
      if (t.contains('python')) {
        titles.addAll({'python developer','python entwickler','softwareentwickler'});
      }
      if (t.contains('javascript') || t.contains('react') || t.contains('frontend')) {
        titles.addAll({'frontend developer','frontend entwickler','webentwickler'});
      }
      if (t.contains('java')) {
        titles.addAll({'java developer','java entwickler','backend entwickler'});
      }
      if (t.contains('system') || t.contains('admin')) {
        titles.addAll({'system administrator','it administrator','system analyst','systemanalytiker'});
      }
      if (t.contains('buchhalt') || t.contains('accounting')) {
        titles.addAll({'buchhalter','accountant','finanzbuchhalter'});
      }
      if (t.contains('controlling')) {
        titles.addAll({'controller','financial controller'});
      }
    }

    // Erfahrung nur als 1 Token
    switch (a.experienceLevel) {
      case 'entry': titles.add('junior'); break;
      case 'mid': titles.add('mid'); break;
      case 'senior': titles.add('senior'); break;
      case 'expert': titles.add('expert'); break;
    }

    final top = titles.where((t) => t.trim().isNotEmpty)
                      .map((t) => t.contains(' ') ? '"$t"' : t)
                      .take(6)
                      .toList();

    return top.isEmpty ? '"softwareentwickler"' : '(${top.join(' OR ')})';
  }

  String _inferJobType(ResumeAnalysisModel a) {
    final text = (a.summary + ' ' + a.skills.join(' ')).toLowerCase();
    
    // Student/Studium erkannt
    if (RegExp(r'student|studium|werkstudent|praktikum|intern|university|hochschule').hasMatch(text)) {
      return 'Werkstudent/Praktikum';
    }
    
    // Teilzeit-Historie
    if (RegExp(r'teilzeit|part.?time|20h|30h|halbtags|part-time').hasMatch(text)) {
      return 'Teilzeit';
    }
    
    // Vollzeit (Standard)
    return 'Vollzeit';
  }

  // Jobs erst beim Button-Klick suchen
  String _composeSerpLocation(ResumeAnalysisModel a) {
    final parts = a.location.split(',').map((s) => s.trim()).toList();
    final city = parts.isNotEmpty ? parts.first : '';
    final country = parts.length >= 2 ? parts.last : 'Germany';

    if (a.postalCode.isNotEmpty && city.isNotEmpty) {
      return '${a.postalCode} $city, $country'; // z.B. 12305 Berlin, Germany
    }
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    return 'Germany';
  }

  Future<List<JobModel>> findJobsForAnalysis(ResumeAnalysisModel a) async {
    final jobService = JobService();
    final loc = _composeSerpLocation(a);
    final query = _buildSmartJobQuery(a);
    
    print('🔍 Smart Query: $query');
    print('📍 Location: $loc');
    print('🎯 Experience Level: ${a.experienceLevel}');
    
    // Erst paginiert suchen
    var jobs = await jobService.searchJobsPaged(
      query: query,
      location: loc,
      experienceLevel: a.experienceLevel,
      maxPages: 3,
    );
    
    // Fallback-Strategie: wenn zu wenig Treffer → 2-3 engere Einzel-Queries
    if (jobs.length < 5) {
      final titles = _topTitlesFromQuery(query);
      for (final t in titles.take(3)) {
        final jq = '"$t"'; // enger suchen
        final more = await jobService.searchJobsPaged(
          query: jq,
          location: loc,
          experienceLevel: a.experienceLevel,
          maxPages: 2,
        );
        jobs.addAll(more);
        if (jobs.length >= 10) break;
      }
    }
    
    // Dedupe
    return _dedupeJobs(jobs);
  }

  Iterable<String> _topTitlesFromQuery(String q) {
    final inside = q.replaceAll('(', '').replaceAll(')', '').replaceAll('"', '');
    return inside.split(' OR ').map((s) => s.trim()).where((s) => s.split(' ').length <= 3);
  }

  List<JobModel> _dedupeJobs(List<JobModel> list) {
    final seen = <String>{};
    return list.where((j) => seen.add('${(j.applicationUrl ?? '').toLowerCase()}|${j.title.toLowerCase()}')).toList();
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
