import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'login_screen.dart';
import '../upload/resume_upload_screen.dart';
import '../main/main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        print('✅ User bereits angemeldet: ${user.uid}');
        
        // Prüfen ob User bereits Lebenslauf hochgeladen hat
        final firestoreService = FirestoreService();
        final hasResume = await firestoreService.userHasResume(user.uid);
        
        if (mounted) {
          if (hasResume) {
            // User hat Lebenslauf → direkt zu Jobs
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          } else {
            // User hat keinen Lebenslauf → Upload Screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ResumeUploadScreen()),
            );
          }
        }
      } else {
        // Kein User angemeldet → Login Screen
        if (mounted) {
          setState(() => _isCheckingAuth = false);
        }
      }
    } catch (e) {
      print('❌ Auth Check Fehler: $e');
      if (mounted) {
        setState(() => _isCheckingAuth = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('App wird geladen...'),
            ],
          ),
        ),
      );
    }

    return const LoginScreen();
  }
}
