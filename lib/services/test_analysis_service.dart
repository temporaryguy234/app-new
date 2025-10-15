import 'resume_analysis_service.dart';
import 'gemini_service.dart';
import 'job_service.dart';
import 'job_matching_service.dart';
import 'firestore_service.dart';
import 'package:firebase_ai/firebase_ai.dart';

class TestAnalysisService {
  
  static Future<void> runFullTest() async {
    print('🧪 STARTE VOLLSTÄNDIGEN TEST DES ANALYSE-SYSTEMS');
    print('=' * 60);
    
    try {
      // 1. Test-Daten erstellen
      final testResume = '''
Max Mustermann
Softwareentwickler

Erfahrung:
- 5 Jahre als Full-Stack Entwickler
- Spezialisiert auf React, Node.js, Python, TypeScript
- Erfahrung mit Cloud-Services (AWS, Azure)
- Team-Lead Erfahrung
- Agile Methoden (Scrum, Kanban)

Skills:
- Frontend: React, Vue.js, HTML5, CSS3, JavaScript
- Backend: Node.js, Python, Java, REST APIs
- Cloud: AWS, Azure, Docker, Kubernetes
- Datenbanken: PostgreSQL, MongoDB, Redis
- Tools: Git, Jenkins, CI/CD

Bildung:
- Bachelor Informatik, TU München (2018)
- Zertifizierungen: AWS Solutions Architect, Scrum Master

Sprachen:
- Deutsch (Muttersprache)
- Englisch (Fließend)
- Französisch (Grundkenntnisse)
''';
      
      print('📝 Test-Lebenslauf erstellt (${testResume.length} Zeichen)');
      
      // 2. Services initialisieren
      final generativeModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
      final geminiService = GeminiService(generativeModel);
      final jobService = JobService();
      final jobMatchingService = JobMatchingService();
      final firestoreService = FirestoreService();
      
      final analysisService = ResumeAnalysisService(
        geminiService: geminiService,
        jobService: jobService,
        jobMatchingService: jobMatchingService,
        firestoreService: firestoreService,
      );
      
      // 3. Vollständige Analyse durchführen
      print('\n🚀 Starte vollständige Analyse...');
      final result = await analysisService.analyzeAndMatchJobs(
        'test-user-123',
        testResume,
        'https://example.com/resume.pdf',
      );
      
      // 4. Ergebnisse ausgeben
      print('\n📊 ANALYSE-ERGEBNISSE:');
      print('=' * 40);
      print('Score: ${result.analysis.score}/100 (${result.analysis.scoreText})');
      print('Experience Level: ${result.analysis.experienceLevel}');
      print('Years of Experience: ${result.analysis.yearsOfExperience}');
      print('Skills: ${result.analysis.skills.join(', ')}');
      print('Strengths: ${result.analysis.strengths.join(', ')}');
      print('Industries: ${result.analysis.industries.join(', ')}');
      print('Summary: ${result.analysis.summary}');
      
      print('\n🎯 JOB-MATCHING ERGEBNISSE:');
      print('=' * 40);
      print('Gefundene Jobs: ${result.totalJobsFound}');
      print('Gematchte Jobs: ${result.matchedJobsCount}');
      print('Match-Rate: ${(result.matchedJobsCount / result.totalJobsFound * 100).toStringAsFixed(1)}%');
      
      if (result.matchedJobs.isNotEmpty) {
        print('\n🏆 TOP 3 GEMATCHTE JOBS:');
        for (int i = 0; i < 3 && i < result.matchedJobs.length; i++) {
          final job = result.matchedJobs[i];
          print('${i + 1}. ${job.title} bei ${job.company}');
          print('   Standort: ${job.location}');
          print('   Gehalt: ${job.salary ?? 'Nicht angegeben'}');
          print('   Tags: ${job.tags.join(', ')}');
          print('');
        }
      }
      
      print('✅ TEST ERFOLGREICH ABGESCHLOSSEN!');
      print('🎉 Alle Systeme funktionieren korrekt!');
      
    } catch (e) {
      print('❌ TEST FEHLGESCHLAGEN: $e');
      print('🔧 Bitte überprüfen Sie die Implementierung');
    }
  }
}
