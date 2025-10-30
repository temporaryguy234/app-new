import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/resume_service.dart';
import '../../services/auth_service.dart';
import '../../config/colors.dart';
import '../scoring/resume_scoring_screen.dart';

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  final ResumeService _resumeService = ResumeService();
  bool _isUploading = false;
  bool _isAnalyzing = false;
  String? _uploadStatus;

  Future<void> _uploadResume() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Datei wird hochgeladen...';
    });

    try {
      // Get current user ID from AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        setState(() {
          _uploadStatus = 'Benutzer nicht angemeldet';
          _isUploading = false;
        });
        return;
      }
      
      final resumeUrl = await _resumeService.uploadResume(user.uid);
      
      setState(() {
        _uploadStatus = 'Datei erfolgreich hochgeladen!';
        _isUploading = false;
      });

      // Start analysis
      _analyzeResume(resumeUrl, user.uid);
      
    } catch (e) {
      setState(() {
        _uploadStatus = 'Upload fehlgeschlagen: $e';
        _isUploading = false;
      });
    }
  }

  Future<void> _analyzeResume(String resumeUrl, String userId) async {
    setState(() {
      _isAnalyzing = true;
      _uploadStatus = 'Lebenslauf wird analysiert...';
    });

    try {
      final analysis = await _resumeService.analyzeResume(userId, resumeUrl);
      
      if (mounted) {
        setState(() {
          _uploadStatus = 'Analyse abgeschlossen!';
          _isAnalyzing = false;
        });
        
        // STATT POP() - zur Analyse navigieren
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResumeScoringScreen(analysis: analysis),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadStatus = 'Analyse fehlgeschlagen: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Lebenslauf hochladen'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Upload area
            Expanded(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: AppColors.blueSurface,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: const Icon(Icons.upload_file, size: 60, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text('Lebenslauf hochladen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('Lade deinen Lebenslauf als PDF oder Word‑Dokument hoch', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading || _isAnalyzing ? null : _uploadResume,
                            icon: _isUploading || _isAnalyzing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : const Icon(Icons.upload),
                            label: Text(_isUploading || _isAnalyzing ? 'Verarbeitung...' : 'Datei auswählen'),
                          ),
                        ),
                        if (_uploadStatus != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _uploadStatus!.contains('fehlgeschlagen') ? AppColors.error.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _uploadStatus!.contains('fehlgeschlagen') ? AppColors.error : AppColors.success),
                            ),
                            child: Row(children: [
                              Icon(_uploadStatus!.contains('fehlgeschlagen') ? Icons.error_outline : Icons.check_circle_outline,
                                  color: _uploadStatus!.contains('fehlgeschlagen') ? AppColors.error : AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_uploadStatus!, style: TextStyle(color: _uploadStatus!.contains('fehlgeschlagen') ? AppColors.error : AppColors.success))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Info section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Unterstützte Formate',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• PDF-Dokumente (.pdf)\n• Word-Dokumente (.doc, .docx)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dein Lebenslauf wird automatisch analysiert und bewertet, um dir passende Job-Empfehlungen zu geben.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
