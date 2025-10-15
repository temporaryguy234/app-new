import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/resume_analysis_model.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  Future<ResumeAnalysisModel> analyzeResume(String resumeText, String userId, String resumeUrl) async {
    try {
      final prompt = _createAnalysisPrompt(resumeText);
      final response = await _callOpenAIAPI(prompt);
      
      return _parseAnalysisResponse(response, userId, resumeUrl);
    } catch (e) {
      throw Exception('OpenAI Analyse fehlgeschlagen: ${e.toString()}');
    }
  }

  String _createAnalysisPrompt(String resumeText) {
    return '''
Analysiere den folgenden Lebenslauf und gib eine detaillierte Bewertung zurück. Antworte NUR im JSON-Format:

{
  "score": [Zahl von 1-100],
  "strengths": ["Stärke1", "Stärke2", "Stärke3"],
  "improvements": ["Verbesserung1", "Verbesserung2", "Verbesserung3"],
  "skills": ["Skill1", "Skill2", "Skill3", "Skill4", "Skill5"],
  "yearsOfExperience": [Zahl der Jahre],
  "industries": ["Branche1", "Branche2", "Branche3"],
  "summary": "2-3 Sätze über das Profil",
  "experienceLevel": "entry/mid/senior/expert"
}

Lebenslauf:
$resumeText
''';
  }

  Future<String> _callOpenAIAPI(String prompt) async {
    final url = Uri.parse(_baseUrl);
    
    final requestBody = {
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content": "Du bist ein Experte für Lebenslauf-Analyse. Antworte nur im JSON-Format."
        },
        {
          "role": "user", 
          "content": prompt
        }
      ],
      "max_tokens": 1000,
      "temperature": 0.3
    };
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiKeys.openaiApiKey}',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI API-Fehler: ${response.statusCode} - ${response.body}');
    }
  }

  ResumeAnalysisModel _parseAnalysisResponse(String response, String userId, String resumeUrl) {
    try {
      String cleanResponse = response.trim();
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
      }
      
      final Map<String, dynamic> data = jsonDecode(cleanResponse);
      
      return ResumeAnalysisModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        resumeUrl: resumeUrl,
        score: (data['score'] ?? 50.0).toDouble(),
        strengths: List<String>.from(data['strengths'] ?? []),
        improvements: List<String>.from(data['improvements'] ?? []),
        skills: List<String>.from(data['skills'] ?? []),
        yearsOfExperience: data['yearsOfExperience'] ?? 0,
        experienceLevel: data['experienceLevel'] ?? 'entry',
        industries: List<String>.from(data['industries'] ?? []),
        summary: data['summary'] ?? 'Keine Zusammenfassung verfügbar',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      // Fallback
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }
}
