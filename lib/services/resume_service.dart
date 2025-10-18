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

  // Intelligente Jobtitel-Ableitung basierend auf Analyse-Daten
  String _buildSmartJobQuery(ResumeAnalysisModel a) {
    final jobTitles = _extractJobTitles(a);
    final employmentTypes = _getEmploymentTypes(a);
    
    // Titel mit Anführungszeichen für exakte Suche
    final titleQueries = jobTitles.map((t) => '"$t"').toList();
    
    // Anstellungsart-Begriffe
    final typeQueries = employmentTypes.toList();
    
    // Kombiniere alles mit OR
    final allQueries = [...titleQueries, ...typeQueries];
    
    if (allQueries.isEmpty) {
      // Fallback: allgemeine Einstiegsjobs
      return '"helfer" OR "aushilfe" OR "minijob" OR "praktikum"';
    }
    
    return '(${allQueries.join(' OR ')})';
  }

  // Jobtitel aus Analyse-Daten extrahieren
  List<String> _extractJobTitles(ResumeAnalysisModel analysis) {
    final titles = <String>{};
    final text = '${analysis.summary} ${analysis.skills.join(' ')} ${analysis.industries.join(' ')}'.toLowerCase();
    
    print('🔍 Analysiere Text: $text');
    
    // Titel-Pattern erkennen (Deutsch + Englisch)
    final titlePatterns = {
      // IT/Development
      r'\b(software|web|app|frontend|backend|full.?stack|mobile|game|embedded)\s*(developer|entwickler|engineer|programmer|programmierer)\b': ['software developer', 'software engineer', 'web developer', 'app developer'],
      r'\b(system|business|data|it)\s*(analyst|analytiker)\b': ['system analyst', 'business analyst', 'data analyst', 'it analyst'],
      r'\b(devops|cloud|aws|azure|kubernetes|docker)\b': ['devops engineer', 'cloud engineer', 'system administrator'],
      r'\b(python|java|javascript|typescript|c\+\+|c#|php|ruby|go|rust|swift|kotlin)\b': ['software developer', 'programmer', 'software engineer'],
      
      // Healthcare/Medical
      r'\b(pflege|krankenpflege|healthcare|medical|nurse|krankenschwester|pfleger)\b': ['pflegefachkraft', 'krankenpfleger', 'healthcare worker', 'nurse'],
      r'\b(arzt|doctor|medizin|medical|therapie|physiotherapie)\b': ['arzt', 'doctor', 'medical assistant', 'therapist'],
      
      // Administration/Office
      r'\b(verwaltung|sachbearbeiter|office|assistant|assistent|sekretär|sekretärin)\b': ['verwaltungsangestellte', 'sachbearbeiter', 'office assistant', 'administrative assistant'],
      r'\b(buchhaltung|accounting|finance|finanz|controller|controlling)\b': ['buchhalter', 'accountant', 'financial analyst', 'controller'],
      
      // Sales/Marketing
      r'\b(verkauf|sales|vertrieb|kundenberatung|customer|account\s*manager)\b': ['verkäufer', 'sales associate', 'kundenberater', 'account manager'],
      r'\b(marketing|werbung|advertising|social\s*media|content|digital)\b': ['marketing manager', 'marketing specialist', 'content manager', 'social media manager'],
      
      // Technical/Trades
      r'\b(elektriker|electrician|elektro|electrical|mechatroniker|mechatronics)\b': ['elektriker', 'electrician', 'electrical engineer', 'mechatronics technician'],
      r'\b(bau|construction|handwerk|craftsman|mechaniker|mechanic)\b': ['bauarbeiter', 'construction worker', 'handwerker', 'mechanic'],
      r'\b(lager|warehouse|logistics|logistik|kommissionierer|picker)\b': ['lagerhelfer', 'warehouse worker', 'lagerarbeiter', 'logistics worker'],
      
      // Hospitality/Service
      r'\b(küche|kitchen|chef|koch|cook|gastronomie|restaurant|hotel)\b': ['küchenhilfe', 'restaurant worker', 'gastronomie', 'chef', 'cook'],
      r'\b(kellner|waiter|service|bedienung|hotel|reception)\b': ['kellner', 'waiter', 'service worker', 'hotel staff'],
      
      // HR/Management
      r'\b(hr|personal|recruiting|recruiter|human\s*resources)\b': ['hr manager', 'recruiter', 'personal manager', 'human resources specialist'],
      r'\b(management|manager|führung|leadership|team\s*lead)\b': ['manager', 'team lead', 'supervisor', 'director'],
      
      // Education/Training
      r'\b(lehre|teacher|lehrer|education|ausbildung|trainer|coach)\b': ['lehrer', 'teacher', 'trainer', 'coach', 'education specialist'],
      
      // Design/Creative
      r'\b(design|grafik|graphic|ui|ux|web\s*design|creative)\b': ['designer', 'graphic designer', 'ui designer', 'ux designer', 'web designer'],
    };
    
    // Pattern-Matching
    for (final entry in titlePatterns.entries) {
      final pattern = RegExp(entry.key, caseSensitive: false);
      if (pattern.hasMatch(text)) {
        titles.addAll(entry.value);
      }
    }
    
    // Synonyme hinzufügen
    final synonyms = <String, List<String>>{
      'software developer': ['programmer', 'software engineer', 'developer', 'programmierer'],
      'system analyst': ['business analyst', 'data analyst', 'it analyst', 'systemanalytiker'],
      'pflegefachkraft': ['krankenpfleger', 'healthcare worker', 'nurse', 'pflegekraft'],
      'verkäufer': ['sales associate', 'kundenberater', 'verkaufskraft', 'sales representative'],
      'lagerhelfer': ['warehouse worker', 'lagerarbeiter', 'logistics worker', 'kommissionierer'],
      'küchenhilfe': ['restaurant worker', 'gastronomie', 'küchenkraft', 'kitchen helper'],
      'elektriker': ['electrician', 'electrical engineer', 'elektrotechniker'],
      'bauarbeiter': ['construction worker', 'handwerker', 'craftsman'],
    };
    
    for (final title in titles.toList()) {
      if (synonyms.containsKey(title)) {
        titles.addAll(synonyms[title]!);
      }
    }
    
    final result = titles.take(8).toList();
    print('🎯 Gefundene Jobtitel: $result');
    return result;
  }

  // Anstellungsart basierend auf Situation
  List<String> _getEmploymentTypes(ResumeAnalysisModel analysis) {
    final types = <String>{};
    final text = '${analysis.summary} ${analysis.skills.join(' ')}'.toLowerCase();
    
    // Schüler/ohne Erfahrung
    if (text.contains('schüler') || text.contains('student') || analysis.yearsOfExperience == 0) {
      types.addAll(['ferienjob', 'minijob', 'aushilfe', 'helfer', 'praktikum']);
    }
    
    // Studierende
    if (text.contains('studium') || text.contains('university') || text.contains('hochschule')) {
      types.addAll(['werkstudent', 'working student', 'praktikum', 'internship']);
    }
    
    // Berufseinsteiger
    if (analysis.experienceLevel == 'entry' || analysis.yearsOfExperience <= 2) {
      types.addAll(['junior', 'assistant', 'associate', 'trainee']);
    }
    
    // Erfahren
    if (analysis.experienceLevel == 'senior' || analysis.experienceLevel == 'expert') {
      types.addAll(['senior', 'lead', 'manager', 'specialist']);
    }
    
    // Teilzeit-Historie
    if (text.contains('teilzeit') || text.contains('part-time')) {
      types.addAll(['teilzeit', 'part-time', 'halbtags']);
    }
    
    final result = types.take(4).toList();
    print('💼 Anstellungsarten: $result');
    return result;
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
