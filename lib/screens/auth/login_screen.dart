import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../config/colors.dart';
import '../upload/resume_upload_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Gradient Header with brand
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: AppColors.blueSurface,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Linku', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      SizedBox(height: 6),
                      Text('Deine Job‑Matching App', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card with social buttons and email form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildLoginButton(
                          text: 'Mit Google anmelden',
                          icon: Icons.login,
                          onPressed: _signInWithGoogle,
                          color: const Color(0xFFDB4437),
                        ),
                        const SizedBox(height: 12),
                        _buildLoginButton(
                          text: 'Mit Facebook anmelden',
                          icon: Icons.facebook,
                          onPressed: _signInWithFacebook,
                          color: const Color(0xFF1877F2),
                        ),
                        if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                          const SizedBox(height: 12),
                          _buildLoginButton(
                            text: 'Mit Apple anmelden',
                            icon: Icons.apple,
                            onPressed: _signInWithApple,
                            color: Colors.black,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(children: const [
                          Expanded(child: Divider()),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('oder')),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 14),
                        _buildEmailPasswordSection(),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() { _isRegisterMode = !_isRegisterMode; });
                          },
                          child: Text(
                            _isRegisterMode ? 'Bereits ein Konto? Anmelden' : 'Noch kein Konto? Registrieren',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(text),
                ],
              ),
      ),
    );
  }

  Widget _buildEmailPasswordSection() {
    return Column(
      children: [
        // Email Field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-Mail',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bitte E-Mail eingeben';
            }
            if (!value.contains('@')) {
              return 'Bitte gültige E-Mail eingeben';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passwort',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bitte Passwort eingeben';
            }
            if (value.length < 6) {
              return 'Passwort muss mindestens 6 Zeichen haben';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Email/Password Login Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_isRegisterMode ? 'Registrieren' : 'Anmelden'),
          ),
        ),
      ],
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      print('✅ Google Login erfolgreich');
      _navigateToUpload();
    } catch (e) {
      _showErrorDialog('Google Login fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithFacebook();
      print('✅ Facebook Login erfolgreich');
      _navigateToUpload();
    } catch (e) {
      _showErrorDialog('Facebook Login fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithApple();
      print('✅ Apple Login erfolgreich');
      _navigateToUpload();
    } catch (e) {
      _showErrorDialog('Apple Login fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (_isRegisterMode) {
        await authService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        print('✅ Registrierung erfolgreich');
      } else {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        print('✅ E-Mail Login erfolgreich');
      }
      
      _navigateToUpload();
    } catch (e) {
      _showErrorDialog(_isRegisterMode 
          ? 'Registrierung fehlgeschlagen: $e'
          : 'E-Mail Login fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToUpload() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ResumeUploadScreen(),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fehler'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}