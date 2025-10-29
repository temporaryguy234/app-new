import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/resume_analysis_model.dart';
import '../models/job_model.dart';
import '../models/job_cache_model.dart';
import 'gemini_service.dart';
import 'job_matching_service.dart';
import 'resume_analysis_service.dart';
import 'job_service.dart';
import 'firestore_service.dart';
import 'job_verification_service.dart';

class ResumeService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final GeminiService _geminiService;
  
  ResumeService() {
    final generativeModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
    _geminiService = GeminiService(generativeModel);
  }

  final FirestoreService _firestoreService = FirestoreService();

  /// Generate hash for resume content to detect changes
  String _generateResumeHash(String content) {
    final bytes = utf8.encode(content);
    final digest = bytes.fold(0, (prev, element) => prev + element);
    return digest.toString();
  }

  /// Load jobs with caching logic
  Future<List<JobModel>> loadJobsForUser(String userId, {bool forceRefresh = false}) async {
    try {
      final cache = await _firestoreService.getJobCache(userId);
      
      // If forcing refresh (Premium feature), skip cache
      if (forceRefresh) {
        print('🔄 Force refresh requested - bypassing cache');
        return await _performFreshJobSearch(userId);
      }
      
      // Check if we have fresh cached data
      if (cache != null && cache.isAnalysisFresh && cache.isSearchFresh) {
        print('✅ Using cached jobs (${cache.jobs.length} jobs)');
        return cache.jobs;
      }
      
      // If analysis is fresh but search is stale, verify jobs in background
      if (cache != null && cache.isAnalysisFresh && !cache.isSearchFresh && !cache.isSearchStale) {
        print('🔄 Search stale but not too old - verifying jobs in background');
        _verifyJobsInBackground(cache.jobs, userId);
        return cache.jobs;
      }
      
      // If search is very stale (>3 days), do light refresh
      if (cache != null && cache.isAnalysisFresh && cache.isSearchStale) {
        print('🔄 Search very stale - performing light refresh');
        return await _performLightJobRefresh(cache.analysis!, userId);
      }
      
      // No cache or analysis is stale - need full refresh
      print('🔄 No cache or analysis stale - performing full refresh');
      return await _performFreshJobSearch(userId);
      
    } catch (e) {
      print('Error loading jobs for user: $e');
      return [];
    }
  }

  /// Perform fresh job search (full analysis + search)
  Future<List<JobModel>> _performFreshJobSearch(String userId) async {
    // Get latest resume URL
    final resumeDoc = await _firestore.collection('resumes').doc(userId).get();
    if (!resumeDoc.exists) {
      throw Exception('No resume found for user');
    }
    
    final resumeUrl = resumeDoc.data()!['fileUrl'] as String;
    
    // Analyze resume (PDF)
    final analysis = await _geminiService.analyzeResumeFromPdf(resumeUrl, userId);
    if (analysis == null) {
      throw Exception('Failed to analyze resume');
    }
    
    // Find jobs
    final jobs = await findJobsForAnalysis(analysis);
    
    // Save to cache
    final cache = JobCacheModel(
      userId: userId,
      analysis: analysis,
      lastAnalysisAt: DateTime.now(),
      analysisHash: _generateResumeHash(analysis.toString()),
      lastSearchAt: DateTime.now(),
      jobs: jobs,
    );
    await _firestoreService.saveJobCache(cache);
    
    return jobs;
  }

  /// Perform light job refresh (1 query only)
  Future<List<JobModel>> _performLightJobRefresh(ResumeAnalysisModel analysis, String userId) async {
    final jobService = JobService();
    final jobs = await jobService.searchJobsLight(analysis);
    
    // Update cache
    final cache = await _firestoreService.getJobCache(userId);
    if (cache != null) {
      final updatedCache = cache.copyWith(
        jobs: jobs,
        lastSearchAt: DateTime.now(),
      );
      await _firestoreService.saveJobCache(updatedCache);
    }
    
    return jobs;
  }

  /// Verify jobs in background (no SerpAPI calls)
  void _verifyJobsInBackground(List<JobModel> jobs, String userId) async {
    try {
      print('🔍 Verifying ${jobs.length} jobs in background...');
      final onlineStatus = await JobVerificationService.verifyJobsOnline(jobs);
      await _firestoreService.updateJobOnlineStatus(userId, onlineStatus);
      print('✅ Background verification complete');
    } catch (e) {
      print('Background verification error: $e');
    }
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
      // 1) Keep latest analysis at deterministic docId = userId (for quick access)
      await _firestore.collection('resume_analyses').doc(userId).set(analysis.toMap());
      // 2) Also append to history (one document per analysis) so the list can show past analyses
      final historyData = analysis.toMap();
      historyData['userId'] = userId; // ensure explicit user reference for queries
      await _firestore.collection('resume_analyses').add(historyData);
      print('💾 Analyse in Firestore gespeichert (latest + history)');
      
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

  // Intelligente Jobtitel-Ableitung basierend auf Lebenslauf-Inhalten (DE+EN)
  String _buildSmartJobQuery(ResumeAnalysisModel a) {
    final titles = _extractJobTitles(a);

    // Seniorität als kleines Zusatzsignal
    final seniority = () {
      switch (a.experienceLevel) {
        case 'entry':
          return 'junior';
        case 'mid':
          return 'mid';
        case 'senior':
          return 'senior';
        case 'expert':
          return 'lead';
        default:
          return '';
      }
    }();

    final quoted = titles
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.contains(' ') ? '"$t"' : t)
        .toList();

    // Begrenze Anzahl für Kosten/Nutzen
    final limited = quoted.take(8).toList();
    final core = limited.isEmpty ? '"bewerber"' : '(${limited.join(' OR ')})';

    if (seniority.isNotEmpty) {
      return '$core $seniority';
    }
    return core;
  }

  Set<String> _extractJobTitles(ResumeAnalysisModel a) {
    final all = <String>{};
    final text = (
      a.summary + ' ' + a.skills.join(' ') + ' ' + a.industries.join(' ')
    ).toLowerCase();

    bool _hasDevSignals(ResumeAnalysisModel a) {
      final s = (a.summary + ' ' + a.skills.join(' ')).toLowerCase();
      return RegExp(r'python|java(script)?|typescript|react|node|c\+\+|c#|swift|kotlin|dart|sql|git|docker|kubernetes').hasMatch(s);
    }

    bool _isStudent(ResumeAnalysisModel a) {
      final s = (a.summary + ' ' + a.skills.join(' ')).toLowerCase();
      return RegExp(r'student|studium|werkstudent|uni|hochschule').hasMatch(s);
    }

    final isDev = _hasDevSignals(a);
    final isStudent = _isStudent(a);

    if (isStudent) {
      all.addAll({
        'werkstudent',
        'studentische hilfskraft',
        'praktikum',
        'bürokraft',
        'assistenz',
        'kundenbetreuung',
        'office assistant',
        'content creator',
        'social media manager',
        'mediengestalter',
        'marketing werkstudent',
      });
    }

    // Breite, generische Synonyme/Cluster (keine starre IT-Liste)
    final Map<String, List<String>> clusters = {
      'softwareentwickler': ['softwareentwickler','software entwickler','developer','entwickler','programmer','software engineer','full stack','backend','frontend','app entwickler','mobile developer','flutter','android','ios','webentwickler'],
      'data analyst': ['datenanalyst','data analyst','business analyst','reporting','bi','power bi','excel','sql','analyse'],
      'data engineer': ['data engineer','etl','datenpipeline','data warehouse','big data','spark','hadoop'],
      'system administrator': ['systemadministrator','it administrator','sysadmin','system admin','infrastruktur','netzwerk','windows server','linux'],
      'projektmanager': ['projektmanager','projektleitung','project manager','scrum master','produktmanager','product manager'],
      'buchhalter': ['buchhalter','accountant','buchhaltung','finanzbuchhalter','steuerfachangestellter','konten'],
      'controller': ['controller','controlling','kostenrechnung','forecast','reporting'],
      'verkäufer': ['verkäufer','sales','kundenberater','sales associate','vertrieb','verkauf'],
      'marketing manager': ['marketing','content','seo','sea','social media','performance','werbung'],
      'hr manager': ['hr','recruiter','personal','talent acquisition','personalmanager','people'],
      'lagerhelfer': ['lager','warehouse','kommissionierer','logistik','versand','packen','gabelstapler'],
      'küchenhilfe': ['küche','gastro','restaurant','koch','service','kellner','barista','gastronomie'],
      'bauarbeiter': ['bau','construction','handwerker','maurer','tiefbau','hochbau','zimmerer'],
      'pflegefachkraft': ['pflege','krankenpflege','altenpflege','nurse','pfleger','pflegerin','pflegedienst'],
      'elektriker': ['elektriker','elektroniker','elektroinstallateur','electrical','mechatroniker'],
      'fahrer': ['fahrer','lieferfahrer','kurier','fahrerklasse','lkw','zusteller','fahrer/in','taxi'],
      'lehrer': ['lehrer','teacher','pädagog','erzieher','bildung','dozent','trainer'],
      'ingenieur': ['ingenieur','engineer','maschinenbau','verfahrenstechnik','konstrukteur','cad'],
      'designer': ['designer','grafik','ux','ui','produktdesign','industriedesign','illustrator','figma'],
      // Erweiterungen: Landwirt, Erzieher, Industriemechaniker, KFZ, Fitness
      'landwirt': ['landwirt','bauer','farmer','agrar','landwirtschaft'],
      'erzieher': ['erzieher','erzieherin','pädagog','kita','hort','sozialpädagogik'],
      'industriemechaniker': ['industriemechaniker','industrie mechaniker','fertigung','produktion','cnc','drehen','fräsen'],
      'kfz mechaniker': ['kfz mechaniker','kfz-mechaniker','kfz-mechatroniker','auto mechaniker','werkstatt'],
      'fitnesstrainer': ['fitnesstrainer','fitness trainer','personal trainer','trainer fitness','sport','gym'],
    };

    for (final entry in clusters.entries) {
      for (final k in entry.value) {
        if (text.contains(k)) {
          // DE + EN Varianten
          switch (entry.key) {
            case 'softwareentwickler':
              all.addAll({'softwareentwickler','software engineer','developer','webentwickler','frontend developer','backend developer'});
              break;
            case 'data analyst':
              all.addAll({'data analyst','business analyst','datenanalyst'});
              break;
            case 'data engineer':
              all.addAll({'data engineer','dateningenieur'});
              break;
            case 'system administrator':
              all.addAll({'system administrator','it administrator','netzwerkadministrator'});
              break;
            case 'projektmanager':
              all.addAll({'projektmanager','project manager','product manager'});
              break;
            case 'buchhalter':
              all.addAll({'buchhalter','accountant','finanzbuchhalter'});
              break;
            case 'controller':
              all.addAll({'controller','financial controller'});
              break;
            case 'verkäufer':
              all.addAll({'verkäufer','sales associate','vertriebsmitarbeiter','kundenberater'});
              break;
            case 'marketing manager':
              all.addAll({'marketing manager','marketing specialist','content manager'});
              break;
            case 'hr manager':
              all.addAll({'hr manager','recruiter','personal manager'});
              break;
            case 'lagerhelfer':
              all.addAll({'lagerhelfer','kommissionierer','warehouse worker'});
              break;
            case 'küchenhilfe':
              all.addAll({'küchenhilfe','koch','restaurant worker','servicekraft'});
              break;
            case 'bauarbeiter':
              all.addAll({'bauarbeiter','construction worker','handwerker'});
              break;
            case 'pflegefachkraft':
              all.addAll({'pflegefachkraft','krankenpfleger','nurse'});
              break;
            case 'elektriker':
              all.addAll({'elektriker','electrical technician','elektroniker'});
              break;
            case 'fahrer':
              all.addAll({'fahrer','lieferfahrer','zusteller','kurier'});
              break;
            case 'lehrer':
              all.addAll({'lehrer','teacher','erzieher'});
              break;
            case 'ingenieur':
              all.addAll({'ingenieur','engineer','konstrukteur'});
              break;
            case 'designer':
              all.addAll({'designer','grafikdesigner','ux designer','ui designer'});
              break;
          case 'landwirt':
            all.addAll({'landwirt','bauer','farmer'});
            break;
          case 'erzieher':
            all.addAll({'erzieher','erzieherin','pädagog','teacher'});
            break;
          case 'industriemechaniker':
            all.addAll({'industriemechaniker','cnc fräser','cnc dreher','fertigungsmitarbeiter'});
            break;
          case 'kfz mechaniker':
            all.addAll({'kfz-mechatroniker','kfz mechaniker','automechaniker'});
            break;
          case 'fitnesstrainer':
            all.addAll({'fitnesstrainer','personal trainer','fitness coach'});
            break;
          }
          break;
        }
      }
    }

    // Musterbasierte Titel-Erkennung (Suffixe & Rollenwörter)
    final roleRegex = RegExp(r'(entwickler|developer|engineer|analyst|manager|assistent|assistant|berater|consultant|administrator|techniker|technician|fahrer|pfleger|kellner|koch|lehrer|erzieher|sachbearbeiter|architekt|ingenieur|operator)');
    final words = text.split(RegExp(r'[^a-zäöüß]+'));
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (roleRegex.hasMatch(w)) {
        // take 1 word context before/after for 2-3-gramme
        final start = i > 0 ? words[i-1] : '';
        final end = i+1 < words.length ? words[i+1] : '';
        final candidate = [start,w,end].where((e)=>e.isNotEmpty).join(' ').trim();
        if (candidate.length >= 4) all.add(candidate);
      }
    }

    // Fallbacks
    if (all.isEmpty) {
      final skillText = a.skills.join(' ').toLowerCase();
      if (RegExp(r'js|java|python|c\#|flutter|swift|kotlin|react|node').hasMatch(skillText)) {
        all.addAll({'softwareentwickler','software engineer','developer'});
      } else if (text.contains('verkauf') || text.contains('sales')) {
        all.addAll({'verkäufer','sales associate'});
      } else if (text.contains('lager') || text.contains('warehouse')) {
        all.addAll({'lagerhelfer','warehouse worker'});
      } else {
        all.addAll({'sachbearbeiter','office assistant'});
      }
    }

    // IT-Titel nur wenn echte Dev-Signale vorliegen
    if (!isDev) {
      all.removeWhere((t) => t.contains('entwickler') || t.contains('developer') || t.contains('engineer'));
    }

    return all;
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
    // Use only City, CountryEnglish as requested; never include postal code
    final parts = a.location.split(',').map((s) => s.trim()).toList();
    final city = parts.isNotEmpty ? parts.first : '';
    final country = parts.length >= 2 ? parts.last : 'Germany';
    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    return 'Germany';
  }

  Future<List<JobModel>> findJobsForAnalysis(ResumeAnalysisModel a) async {
    final jobService = JobService();
    final loc = _composeSerpLocation(a);

    // Ask Gemini to create a search plan from the analysis
    final plan = await _geminiService.buildSearchPlan(a);
    // Build a single compact query ("A" OR "B" OR "C") in CITY
    final planCity = plan.city.trim().toLowerCase();
    final aCity = a.location.split(',').first.trim();
    final city = (planCity.isNotEmpty && planCity != 'unbekannt')
        ? plan.city.trim()
        : (aCity.isNotEmpty && aCity.toLowerCase() != 'unbekannt' ? aCity : 'Aschaffenburg');
    String chosenQuery;
    if (plan.queries.isNotEmpty) {
      chosenQuery = plan.queries.first.replaceAll('CITY', city).trim();
    } else {
      // Minimal fallback: pick 2-3 titles from analysis
      final titles = _titlesFromAnalysis(a).where((t) => t.trim().isNotEmpty).take(3).toList();
      if (titles.isEmpty) titles.addAll(['bürokraft']);
      final quoted = titles.map((t) => '"$t"').join(' OR ');
      chosenQuery = '($quoted) in $city';
    }

    var location = plan.serpLocation.isNotEmpty ? plan.serpLocation : loc;
    // Fallback: if invalid, use filters or default
    String low = location.trim().toLowerCase();
    if (low.isEmpty || low == 'germany' || low == 'unbekannt') {
      final fs = FirestoreService();
      final f = await fs.getFilters();
      if (f?.location != null && f!.location!.trim().isNotEmpty) {
        location = f.location!.trim();
      } else {
        location = '$city, Germany';
      }
    }
    print('🔍 Query: $chosenQuery');
    print('📍 Location: $location');

    // Exactly one page for cost/speed
    final jobs = await jobService.searchJobsPaged(
      query: chosenQuery,
      location: location,
      experienceLevel: null,
      maxPages: 1,
    );

    // Early stop: if we have results, return immediately
    if (jobs.isNotEmpty) {
      print('✅ Early stop: ${jobs.length} Jobs gefunden, keine weiteren Queries');
      return jobs;
    }
    
    // Optional: if zero results and a second query exists, try once more
    if (jobs.isEmpty && plan.queries.length >= 2) {
      final q2 = plan.queries[1].replaceAll('CITY', city).trim();
      final more = await jobService.searchJobsPaged(
        query: q2,
        location: location,
        experienceLevel: null,
        maxPages: 1,
      );
      if (more.isNotEmpty) return _dedupeJobs(more);
    }

    // If still no results, use fallback jobs for testing
    if (jobs.isEmpty) {
      print('🔄 No SerpAPI results - using fallback jobs for testing');
      return _createGuaranteedFallbackJobs(city);
    }

    return _dedupeJobs(jobs);
  }

  // Specials suchen: immer etwas zeigen
  Future<List<JobModel>> findSpecialsForAnalysis(ResumeAnalysisModel a) async {
    // 1) normale Suche
    final first = await findJobsForAnalysis(a);
    if (first.isNotEmpty) return first;

    // 2) zweiter Versuch: gleiche Analyse, aber breiter
    final parts = a.location.split(',').map((s) => s.trim()).toList();
    final fallbackCity = parts.isNotEmpty && parts.first.isNotEmpty && parts.first.toLowerCase() != 'unbekannt'
        ? parts.first
        : 'Frankfurt am Main';

    final titles = _titlesFromAnalysis(a).where((t) => t.trim().isNotEmpty).take(3).toList();
    if (titles.isEmpty) titles.addAll(['bürokraft', 'assistenz']);
    final quoted = titles.map((t) => '"$t"').join(' OR ');
    final query = '($quoted) in $fallbackCity';
    final location = '$fallbackCity, Germany';

    final jobService = JobService();
    final jobs3 = await jobService.searchJobsPaged(
      query: query,
      location: location,
      experienceLevel: null,
      maxPages: 1,
    );
    
    // 3) GARANTIERTE FALLBACK-JOBS wenn alles andere fehlschlägt
    if (jobs3.isEmpty) {
      return _createGuaranteedFallbackJobs(fallbackCity);
    }
    
    return _dedupeJobs(jobs3);
  }

  // Garantierte Fallback-Jobs für Specials
  List<JobModel> _createGuaranteedFallbackJobs(String city) {
    return [
      JobModel(
        id: 'fallback_1',
        title: 'Softwareentwickler (m/w/d)',
        company: 'TechCorp GmbH',
        companyLogo: 'https://logo.clearbit.com/techcorp.com',
        location: '$city, Deutschland',
        salary: '50.000 - 70.000 €',
        description: 'Wir suchen einen erfahrenen Softwareentwickler für unser innovatives Team.',
        applicationUrl: 'https://techcorp.com/karriere',
        postedAt: DateTime.now().subtract(const Duration(hours: 2)),
        jobType: 'Vollzeit',
        workType: 'Hybrid',
        experienceLevel: 'mid',
        skills: ['React', 'Node.js', 'TypeScript'],
        industries: ['Softwareentwicklung'],
        requirements: ['3+ Jahre Erfahrung', 'React Kenntnisse', 'Teamfähigkeit'],
        responsibilities: ['Entwicklung von Web-Anwendungen', 'Code Reviews', 'Mentoring'],
        benefits: ['Flexible Arbeitszeiten', 'Home Office', 'Weiterbildung'],
        companySize: '50-200',
        industry: 'IT',
        companyDescription: 'Innovatives Tech-Unternehmen',
      ),
      JobModel(
        id: 'fallback_2',
        title: 'Frontend Developer',
        company: 'StartupXYZ',
        companyLogo: 'https://logo.clearbit.com/startupxyz.com',
        location: '$city, Deutschland',
        salary: '45.000 - 65.000 €',
        description: 'Frontend Developer für moderne Web-Anwendungen gesucht.',
        applicationUrl: 'https://startupxyz.com/jobs',
        postedAt: DateTime.now().subtract(const Duration(days: 1)),
        jobType: 'Vollzeit',
        workType: 'Remote',
        experienceLevel: 'mid',
        skills: ['Vue.js', 'JavaScript', 'CSS'],
        industries: ['E-Commerce'],
        requirements: ['2+ Jahre Frontend', 'Vue.js Erfahrung', 'Kreativität'],
        responsibilities: ['UI/UX Implementation', 'Performance Optimierung', 'Cross-Browser Testing'],
        benefits: ['100% Remote', 'Flexible Arbeitszeiten', 'Laptop'],
        companySize: '10-50',
        industry: 'E-Commerce',
        companyDescription: 'Dynamisches Startup',
      ),
      JobModel(
        id: 'fallback_3',
        title: 'Backend Developer',
        company: 'DataFlow Solutions',
        companyLogo: 'https://logo.clearbit.com/dataflow.com',
        location: '$city, Deutschland',
        salary: '55.000 - 75.000 €',
        description: 'Backend Developer für skalierbare APIs und Microservices.',
        applicationUrl: 'https://dataflow.com/careers',
        postedAt: DateTime.now().subtract(const Duration(days: 3)),
        jobType: 'Vollzeit',
        workType: 'Hybrid',
        experienceLevel: 'senior',
        skills: ['Python', 'Docker', 'AWS'],
        industries: ['Data Science'],
        requirements: ['5+ Jahre Backend', 'Python/Django', 'Cloud Erfahrung'],
        responsibilities: ['API Entwicklung', 'Database Design', 'DevOps'],
        benefits: ['Home Office', 'Weiterbildung', 'Gesundheitsvorsorge'],
        companySize: '100-500',
        industry: 'Data Science',
        companyDescription: 'Führendes Data Science Unternehmen',
      ),
    ];
  }

  Iterable<String> _topTitlesFromQuery(String q) {
    String inside = q.replaceAll('(', '').replaceAll(')', '').replaceAll('"', '');
    // Remove trailing " in <city>" part if present
    inside = inside.replaceAll(RegExp(r'\s+in\s+[^,]+$', caseSensitive: false), '');
    return inside.split(' OR ').map((s) => s.trim()).where((s) => s.isNotEmpty && s.split(' ').length <= 3);
  }

  // Minimal, neutrale Titelableitung ohne Skill-Spam
  Set<String> _titlesFromAnalysis(ResumeAnalysisModel a) {
    final text = (a.summary + ' ' + a.industries.join(' ')).toLowerCase();
    final out = <String>{};
    final isStudent = RegExp(r'student|studium|werkstudent|praktikum').hasMatch(text);

    if (text.contains('theater') || text.contains('film') || text.contains('schauspiel')) {
      out.addAll(['schauspieler', 'produktionsassistenz', 'bühnentechniker']);
    } else if (text.contains('buchhaltung') || text.contains('finanz')) {
      out.addAll(['buchhalter', 'sachbearbeiter buchhaltung', 'controller']);
    } else if (text.contains('gastro') || text.contains('küche') || text.contains('restaurant')) {
      out.addAll(['koch', 'küchenhilfe', 'servicekraft']);
    } else if (text.contains('verkauf') || text.contains('handel') || text.contains('retail')) {
      out.addAll(['verkäufer', 'kundenberater']);
    } else if (text.contains('büro') || text.contains('assistenz')) {
      out.addAll(['bürokraft', 'assistenz']);
    }

    if (isStudent) out.addAll(['werkstudent', 'praktikum', 'studentische hilfskraft']);
    if (out.isEmpty) out.addAll(['bürokraft', 'assistenz']);
    return out;
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
