import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/resume_analysis_model.dart';

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
  
  Future<ResumeAnalysisModel> analyzeResume(String resumeText, String userId, String resumeUrl) async {
    try {
      print('🤖 Starte Gemini-Analyse für User: $userId');
      print('📄 Resume Text Länge: ${resumeText.length} Zeichen');
      
      final prompt = _createAnalysisPrompt(resumeText);
      print('📝 Prompt erstellt, starte Firebase AI Call...');
      
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.0,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        ),
      );
      final text = response.text ?? '';
      if (text.trim().isEmpty) {
        print('⚠️ Firebase AI lieferte leeren Text (max_tokens). Fallback wird verwendet.');
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
      
      // PDF von Firebase Storage laden
      final bytes = await _loadPdfFromStorage(pdfUrl);
      print('📄 PDF geladen: ${bytes.length} Bytes');
      
      // Multimodaler Prompt
      final prompt = """
      Analysiere den angehängten Lebenslauf. Antworte NUR mit einem gültigen JSON ohne zusätzlichen Text:

      {
        "score": number,                   // 1-100
        "strengths": [string],
        "improvements": [string], 
        "skills": [string],
        "yearsOfExperience": number,
        "industries": [string],
        "summary": string,
        "experienceLevel": "entry" | "mid" | "senior" | "expert",
        "location": "string"               // Aktueller Standort (Stadt, Land)
      }

      Bewertungskriterien:
      - score: 1-100 basierend auf Vollständigkeit, Relevanz, Formatierung
      - strengths: 3-5 Hauptstärken des Kandidaten
      - improvements: 3-5 konkrete Verbesserungsvorschläge
      - skills: 5-10 erkannte technische und soft skills
      - yearsOfExperience: Geschätzte Berufserfahrung in Jahren
      - industries: 2-3 relevante Branchen
      - summary: Kurze Zusammenfassung des Profils
      - experienceLevel: entry (0-2 Jahre), mid (3-5 Jahre), senior (6-10 Jahre), expert (10+ Jahre)
      - location: Aktueller Standort aus dem Lebenslauf (Stadt, Land) - z.B. "München, Deutschland", "Wien, Österreich", "Zürich, Schweiz"
      """;

      print('📝 Multimodaler Prompt erstellt, starte Firebase AI Call...');
      
      // Multimodale Anfrage: Text + PDF
      final response = await _model.generateContent(
        [Content.multi([TextPart(prompt), InlineDataPart('application/pdf', bytes)])],
        generationConfig: GenerationConfig(
          temperature: 0.0,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        ),
      );
      
      final text = response.text ?? '{}';
      if (text.trim().isEmpty) {
        print('⚠️ Firebase AI lieferte leeren Text (max_tokens). Fallback wird verwendet.');
      }
      print('✅ Firebase AI Response erhalten: ${text.length} Zeichen');
      
      final analysis = _parseAnalysisResponse(text, userId, pdfUrl);
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
      print('🔍 Raw Response: ${response.substring(0, response.length.clamp(0, 100))}...');
      
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
      print('🔍 Cleaned Response: ${cleanResponse.substring(0, cleanResponse.length.clamp(0, 100))}...');
      
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }
}
