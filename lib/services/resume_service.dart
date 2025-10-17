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
    final jobTitles = <String>{};
    
    // Skills zu echten Jobtiteln mappen
    for (final skill in a.skills) {
      final s = skill.toLowerCase();
      
      // Data/BI Bereich
      if (s.contains('data') || s.contains('analys') || s.contains('statistik')) {
        jobTitles.addAll(['data analyst', 'business analyst', 'business intelligence analyst', 'data scientist']);
      }
      if (s.contains('sql') || s.contains('database') || s.contains('datenbank')) {
        jobTitles.addAll(['data engineer', 'database developer', 'sql developer', 'data analyst']);
      }
      
      // Development
      if (s.contains('python')) {
        jobTitles.addAll(['python developer', 'software engineer', 'backend developer']);
      }
      if (s.contains('javascript') || s.contains('react') || s.contains('vue') || s.contains('angular')) {
        jobTitles.addAll(['frontend developer', 'web developer', 'javascript developer', 'react developer']);
      }
      if (s.contains('java')) {
        jobTitles.addAll(['java developer', 'backend developer', 'software engineer']);
      }
      if (s.contains('c#') || s.contains('csharp')) {
        jobTitles.addAll(['c# developer', '.net developer', 'software engineer']);
      }
      
      // System/IT
      if (s.contains('system') || s.contains('admin') || s.contains('server')) {
        jobTitles.addAll(['system administrator', 'it specialist', 'system analyst', 'it administrator']);
      }
      if (s.contains('network') || s.contains('security') || s.contains('sicherheit')) {
        jobTitles.addAll(['network engineer', 'security specialist', 'cybersecurity analyst']);
      }
      if (s.contains('cloud') || s.contains('aws') || s.contains('azure')) {
        jobTitles.addAll(['cloud engineer', 'devops engineer', 'cloud architect']);
      }
      
      // Business/Management
      if (s.contains('consult') || s.contains('berat') || s.contains('consulting')) {
        jobTitles.addAll(['consultant', 'business consultant', 'management consultant']);
      }
      if (s.contains('project') || s.contains('management') || s.contains('projekt')) {
        jobTitles.addAll(['project manager', 'project coordinator', 'program manager']);
      }
      if (s.contains('marketing') || s.contains('sales') || s.contains('vertrieb')) {
        jobTitles.addAll(['marketing specialist', 'sales manager', 'account manager']);
      }
      
      // Finance/Accounting
      if (s.contains('buchhalt') || s.contains('accounting') || s.contains('finanz')) {
        jobTitles.addAll(['buchhalter', 'accountant', 'financial analyst', 'finanzbuchhalter']);
      }
      if (s.contains('controlling') || s.contains('finance') || s.contains('controlling')) {
        jobTitles.addAll(['controller', 'financial controller', 'cost accountant']);
      }
      
      // HR/Personal
      if (s.contains('hr') || s.contains('personal') || s.contains('recruiting')) {
        jobTitles.addAll(['hr specialist', 'recruiter', 'personal manager']);
      }
      
      // Design/Creative
      if (s.contains('design') || s.contains('ui') || s.contains('ux')) {
        jobTitles.addAll(['ui designer', 'ux designer', 'graphic designer', 'web designer']);
      }
      
      // Engineering
      if (s.contains('engineer') || s.contains('ingenieur') || s.contains('technik')) {
        jobTitles.addAll(['engineer', 'technical specialist', 'process engineer']);
      }
    }
    
    // Experience Level hinzufügen
    switch (a.experienceLevel) {
      case 'entry':
        jobTitles.addAll(['junior', 'trainee', 'entry level', 'graduate', 'starter']);
        break;
      case 'mid':
        jobTitles.addAll(['mid level', 'experienced', 'specialist']);
        break;
      case 'senior':
        jobTitles.addAll(['senior', 'lead', 'manager', 'expert']);
        break;
      case 'expert':
        jobTitles.addAll(['expert', 'principal', 'architect', 'director']);
        break;
    }
    
    // Jobtyp basierend auf Lebenslauf ableiten
    final jobType = _inferJobType(a);
    if (jobType == 'Teilzeit') {
      jobTitles.add('teilzeit');
    } else if (jobType == 'Werkstudent/Praktikum') {
      jobTitles.addAll(['werkstudent', 'praktikum', 'internship', 'working student']);
    }
    
    // Industries als Jobtitel hinzufügen
    for (final industry in a.industries) {
      final i = industry.toLowerCase();
      if (i.contains('fintech') || i.contains('banking')) {
        jobTitles.addAll(['fintech specialist', 'banking analyst', 'financial technology']);
      }
      if (i.contains('e-commerce') || i.contains('retail')) {
        jobTitles.addAll(['e-commerce specialist', 'online marketing', 'digital commerce']);
      }
      if (i.contains('healthcare') || i.contains('medizin')) {
        jobTitles.addAll(['healthcare analyst', 'medical technology', 'pharma specialist']);
      }
      if (i.contains('automotive') || i.contains('auto')) {
        jobTitles.addAll(['automotive engineer', 'mobility specialist', 'car technology']);
      }
    }
    
    // Top 10 relevante Titel nehmen und mit OR verknüpfen
    final topTitles = jobTitles.take(10).toList();
    if (topTitles.isEmpty) return 'software developer';
    
    return '(' + topTitles.join(' OR ') + ')';
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
  Future<List<JobModel>> findJobsForAnalysis(ResumeAnalysisModel a) async {
    final jobService = JobService();
    final loc = (a.location.isNotEmpty && a.location.toLowerCase() != 'unbekannt') 
        ? a.location 
        : 'Germany';
    final query = _buildSmartJobQuery(a);
    
    print('🔍 Smart Query: $query');
    print('📍 Location: $loc');
    print('🎯 Experience Level: ${a.experienceLevel}');
    
    return await jobService.searchJobs(
      query: query,
      location: loc,
      experienceLevel: a.experienceLevel,
    );
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
