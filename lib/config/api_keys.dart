class ApiKeys {
  // Secrets are injected via --dart-define at build/run time.
  // Never commit real keys to the repository.

  // Gemini API Key
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  // OpenAI API Key
  static const String openaiApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');

  // SerpAPI Key
  static const String serpApiKey = String.fromEnvironment('SERPAPI_KEY', defaultValue: '');

  // Firebase Config (web targets typically require these at runtime via Firebase options)
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String firebaseWebApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
}