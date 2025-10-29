import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/resume_analysis_model.dart';
import '../models/search_plan_model.dart';

// Helper casts for robust JSON parsing from LLMs
num? _asNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

List<String> _asStrings(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

String _toEnglishCountry(String s) {
  final l = s.toLowerCase();
  if (l.contains('deutschland') || l == 'de') return 'Germany';
  if (l.contains('österreich') || l == 'at' || l.contains('austria')) return 'Austria';
  if (l.contains('schweiz') || l == 'ch' || l.contains('switzerland')) return 'Switzerland';
  return s;
}

String _normalizeResumeLocationToEnglish(dynamic v) {
  final raw = v?.toString().trim() ?? '';
  if (raw.isEmpty) return 'Unbekannt';
  final parts = raw.split(',').map((s) => s.trim()).toList();
  if (parts.length >= 2) {
    final city = parts.first;
    final countryEn = _toEnglishCountry(parts.sublist(1).join(', '));
    return '$city, $countryEn';
  }
  return raw
      .replaceAll(RegExp(r'Deutschland', caseSensitive: false), 'Germany')
      .replaceAll(RegExp(r'Österreich', caseSensitive: false), 'Austria')
      .replaceAll(RegExp(r'Schweiz', caseSensitive: false), 'Switzerland');
}

class GeminiService {
  final GenerativeModel _model;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  GeminiService(this._model);

  // Build a search plan from an existing analysis. Returns structured guidance
  // for SerpAPI queries using only City, CountryEnglish as location.
  Future<SearchPlan> buildSearchPlan(ResumeAnalysisModel analysis) async {
    try {
      final loc = analysis.location;
      final city = loc.split(',').map((s) => s.trim()).first;
      final countryEn = loc.contains(',') ? loc.split(',').map((s) => s.trim()).last : '';
      final serpLocation = (city.isNotEmpty && countryEn.isNotEmpty) ? '$city, $countryEn' : loc;

      final prompt = '''
AUFGABE
Ich stelle auf Basis einer Lebenslauf-Analyse perfekte Suchanfragen für Google Jobs zusammen, damit passende Stellen für diese Person gefunden werden.

EINGABEN
- Analyse-Daten (JSON): {
  "skills": ${jsonEncode(analysis.skills)},
  "yearsOfExperience": ${analysis.yearsOfExperience},
  "experienceLevel": "${analysis.experienceLevel}",
  "industries": ${jsonEncode(analysis.industries)},
  "summary": ${jsonEncode(analysis.summary)},
  "location": ${jsonEncode(analysis.location)}
}

ZIEL
- Formuliere 1 bis 3 kompakte Google-Suchanfragen in deutscher Sprache.
- Jede Suchanfrage bündelt mehrere passende Jobtitel mit OR und endet mit "in CITY".
- Die Suchanfragen enthalten NICHT das Land.
- Liefere zusätzlich die Stadt und das Land separat, damit ich sie für SerpAPI-Filter nutzen kann.
- Nutze realistische Jobtitel, die zu Fähigkeiten, Erfahrung, Studium und aktueller Situation passen (z. B. Werkstudent, Praktikum, Minijob, Teilzeit, Vollzeit, Ferienjob, Studentenjob, Aushilfe, Nebenjob).

REGELN
- Ausschließlich Deutsch.
- Ausschließlich ein gültiges JSON-Objekt als Ausgabe, ohne weiteren Text.
- Maximal 8 Titel pro Query, alle Titel in Anführungszeichen, zwischen den Titeln OR verwenden.
- Maximal 3 Queries, minimal 1 Query.
- Stadt aus den Eingaben verwenden. Kein Land in den Suchanfragen.
- Land nur separat zurückgeben, damit es für die SerpAPI-Filter genutzt werden kann.

AUSGABEFORMAT (JSON)
{
  "city": ${jsonEncode(city)},
  "countryEnglish": ${jsonEncode(countryEn)},
  "serpLocation": ${jsonEncode(serpLocation)},
  "queries": [
    "(\"Titel 1\" OR \"Titel 2\" OR \"Titel 3\") in CITY"
  ],
  "titles": [
    "Titel 1", "Titel 2", "Titel 3"
  ],
  "jobTypes": [
    "Werkstudent", "Praktikum", "Teilzeit", "Vollzeit", "Minijob", "Ferienjob", "Studentenjob", "Aushilfe", "Nebenjob"
  ]
}

BEISPIELE (nur zur Orientierung, NICHT ausgeben)
- Beispiel 1 (Student/in Büro/Service):
  queries: [
    "(\"werkstudent\" OR \"studentische hilfskraft\" OR \"bürokraft\" OR \"assistenz\" OR \"kundenservice\") in CITY"
  ]

- Beispiel 2 (Kaufmännisch/Finanzen):
  queries: [
    "(\"buchhalter\" OR \"bilanzbuchhalter\" OR \"finanzbuchhalter\" OR \"sachbearbeiter buchhaltung\") in CITY",
    "(\"controller\" OR \"junior controller\" OR \"finanzcontroller\") in CITY"
  ]

- Beispiel 3 (Gastronomie/Küche):
  queries: [
    "(\"koch\" OR \"küchenhilfe\" OR \"servicekraft\" OR \"restaurantmitarbeiter\") in CITY"
  ]
''';

      // Try with higher token limit, then a single retry if empty
      String text = '';
      try {
        final response = await _model.generateContent(
          [Content.text(prompt)],
          generationConfig: GenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 4096,
            responseMimeType: 'application/json',
          ),
        );
        text = response.text ?? '';
      } catch (_) {}

      if (text.trim().isEmpty) {
        try {
          final retry = await _model.generateContent(
            [Content.text(prompt)],
            generationConfig: GenerationConfig(
              temperature: 0.2,
              maxOutputTokens: 3072,
              responseMimeType: 'application/json',
            ),
          );
          text = retry.text ?? '';
        } catch (_) {}
      }

      if (text.trim().isEmpty) return SearchPlan.empty();
      return SearchPlan.fromJson(text);
    } catch (e) {
      return SearchPlan.empty();
    }
  }
  
  Future<ResumeAnalysisModel> analyzeResume(String resumeText, String userId, String resumeUrl) async {
    try {
      print('🤖 Starte Gemini-Analyse für User: $userId');
      print('📄 Resume Text Länge: ${resumeText.length} Zeichen');
      
      final prompt = _createAnalysisPrompt(resumeText);
      print('📝 Prompt erstellt, starte Firebase AI Call...');
      
      // First attempt with higher token limit
      String text = '';
      try {
        final response = await _model.generateContent(
          [Content.text(prompt)],
          generationConfig: GenerationConfig(
            temperature: 0.0,
            maxOutputTokens: 4096,
            responseMimeType: 'application/json',
          ),
        );
        text = response.text ?? '';
      } catch (_) {}

      // Single retry if empty
      if (text.trim().isEmpty) {
        print('⚠️ Firebase AI lieferte leeren Text (max_tokens). Starte Retry...');
        try {
          final retry = await _model.generateContent(
            [Content.text(prompt)],
            generationConfig: GenerationConfig(
              temperature: 0.1,
              maxOutputTokens: 3072,
              responseMimeType: 'application/json',
            ),
          );
          text = retry.text ?? '';
        } catch (_) {}
      }

      if (text.trim().isEmpty) {
        print('⚠️ Firebase AI lieferte erneut leeren Text. Fallback-Parser wird verwendet.');
      }
      print('✅ Firebase AI Response erhalten: ${text.length} Zeichen');
      
      final analysis = _parseAnalysisResponse(text, userId, resumeUrl);
      print('🎯 Analyse erfolgreich: Score ${analysis.score}/100');
      
      return analysis;
    } catch (e) {
      print('❌ Gemini-Analyse fehlgeschlagen: $e');
      throw Exception('Lebenslauf-Analyse fehlgeschlagen: ${e.toString()}');
    }
  }

  Future<ResumeAnalysisModel> analyzeResumeFromPdf(String pdfUrl, String userId) async {
    try {
      print('🤖 Starte PDF-Analyse für User: $userId');
      print('📄 PDF URL: $pdfUrl');
      
      // PDF laden und Text extrahieren (robust gegen max_tokens)
      final bytes = await _loadPdfFromStorage(pdfUrl);
      print('📄 PDF geladen: ${bytes.length} Bytes');
      final pdf = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(pdf);
      var extracted = extractor.extractText();
      pdf.dispose();
      if (extracted.length > 18000) extracted = extracted.substring(0, 18000);

      print('📝 Text extrahiert (${extracted.length} Zeichen), starte Analyse...');
      final analysis = await analyzeResume(extracted, userId, pdfUrl);
      print('🎯 PDF-Analyse erfolgreich: Score ${analysis.score}/100');
      
      return analysis;
    } catch (e) {
      print('❌ PDF-Analyse fehlgeschlagen: $e');
      throw Exception('PDF-Analyse fehlgeschlagen: ${e.toString()}');
    }
  }

  Future<Uint8List> _loadPdfFromStorage(String pdfUrl) async {
    try {
      // Firebase Storage Reference aus URL erstellen
      final ref = _storage.refFromURL(pdfUrl);
      
      // PDF als Bytes laden (max 10MB)
      final bytes = await ref.getData(10 * 1024 * 1024);
      
      if (bytes == null) {
        throw Exception('PDF konnte nicht geladen werden');
      }
      
      return bytes;
    } catch (e) {
      print('❌ PDF-Loading fehlgeschlagen: $e');
      throw Exception('PDF-Loading fehlgeschlagen: ${e.toString()}');
    }
  }

  String _createAnalysisPrompt(String resumeText) {
    return '''
Analysiere den folgenden Lebenslauf und gib eine detaillierte Bewertung zurück. Antworte NUR im JSON-Format ohne zusätzlichen Text:

{
  "score": [Zahl von 1-100],
  "strengths": ["Stärke1", "Stärke2", "Stärke3"],
  "improvements": ["Verbesserung1", "Verbesserung2", "Verbesserung3"],
  "skills": ["Skill1", "Skill2", "Skill3", "Skill4", "Skill5"],
  "yearsOfExperience": [Zahl der Jahre],
  "industries": ["Branche1", "Branche2", "Branche3"],
  "summary": "2-3 Sätze über das Profil und die Erfahrung",
  "location": "string",
  "postalCode": "string | null",
  "experienceLevel": "entry/mid/senior/expert"
}

Lebenslauf:
$resumeText

Bewertungskriterien:
- score: 1-100 basierend auf Vollständigkeit, Relevanz, Formatierung
- strengths: 3-5 Hauptstärken des Kandidaten
- improvements: 3-5 konkrete Verbesserungsvorschläge
- skills: 5-10 erkannte technische und soft skills
- yearsOfExperience: Geschätzte Berufserfahrung in Jahren
- industries: 2-3 relevante Branchen
- summary: Kurze Zusammenfassung des Profils
- experienceLevel: entry (0-2 Jahre), mid (3-5 Jahre), senior (6-10 Jahre), expert (10+ Jahre)
''';
  }


  ResumeAnalysisModel _parseAnalysisResponse(String response, String userId, String resumeUrl) {
    try {
      final rawPreviewEnd = response.length > 100 ? 100 : response.length;
      print('🔍 Raw Response: ${response.substring(0, rawPreviewEnd)}...');
      
      // Clean the response to extract JSON
      String cleanResponse = response.trim();
      
      // STRIP ALL MARKDOWN CODE BLOCKS
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7); // Remove ```json
        print('🔧 Removed ```json prefix');
      }
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.substring(3); // Remove ```
        print('🔧 Removed ``` prefix');
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3); // Remove trailing ```
        print('🔧 Removed ``` suffix');
      }
      
      // Additional cleaning for newlines
      cleanResponse = cleanResponse.trim();
      final cleanPreviewEnd = cleanResponse.length > 100 ? 100 : cleanResponse.length;
      print('🔍 Cleaned Response: ${cleanResponse.substring(0, cleanPreviewEnd)}...');
      
      final Map<String, dynamic> data = jsonDecode(cleanResponse);

      final double score = (_asNum(data['score'])?.toDouble()) ?? 50.0;
      final int years = (_asNum(data['yearsOfExperience'])?.toInt()) ?? 0;

      return ResumeAnalysisModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        resumeUrl: resumeUrl,
        score: score,
        strengths: _asStrings(data['strengths']),
        improvements: _asStrings(data['improvements']),
        skills: _asStrings(data['skills']),
        yearsOfExperience: years,
        experienceLevel: (data['experienceLevel']?.toString() ?? 'entry'),
        industries: _asStrings(data['industries']),
        summary: data['summary']?.toString() ?? 'Keine Zusammenfassung verfügbar',
        location: _normalizeResumeLocationToEnglish(data['location']),
        postalCode: (data['postalCode']?.toString() ?? '').isEmpty
            ? _extractPostalFromLocation(data['location'])
            : data['postalCode'].toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      // Fallback if JSON parsing fails
      return ResumeAnalysisModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        resumeUrl: resumeUrl,
        score: 50.0,
        strengths: ['Grundlegende Fähigkeiten'],
        improvements: ['Lebenslauf verbessern'],
        skills: ['Allgemeine Fähigkeiten'],
        yearsOfExperience: 0,
        experienceLevel: 'entry',
        industries: ['Allgemein'],
        summary: 'Grundlegende Analyse verfügbar',
        location: 'Unbekannt',
        postalCode: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  String _extractPostalFromLocation(dynamic loc) {
    final s = (loc?.toString() ?? '').trim();
    final m = RegExp(r'(^|\s)(\d{4,5})(?=\s|,|$)').firstMatch(s);
    return m?.group(2) ?? '';
  }
}
