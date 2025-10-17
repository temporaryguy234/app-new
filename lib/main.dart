import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'screens/main/main_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'services/test_analysis_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Gemini Model
  final generativeModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  
  // 🧪 TESTE ANALYSE-SYSTEM (nur im Debug-Modus, nicht blockierend)
  if (kDebugMode) {
    Future.microtask(() => TestAnalysisService.runFullTest());
  }
  
  runApp(LinkuApp(generativeModel: generativeModel));
}

class LinkuApp extends StatelessWidget {
  final GenerativeModel generativeModel;
  
  const LinkuApp({super.key, required this.generativeModel});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<GenerativeModel>(
          create: (_) => generativeModel,
        ),
      ],
      child: MaterialApp(
        title: 'Linku',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
        routes: {
          '/main': (context) => const MainScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}