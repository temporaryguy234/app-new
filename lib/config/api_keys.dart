class ApiKeys {
  // Read secrets from --dart-define at build time. Defaults are empty to avoid leaking keys.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String serpApiKey = String.fromEnvironment('SERP_API_KEY', defaultValue: '');
  
  // Firebase project values should come from configuration, not source control
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String firebaseWebApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
}