import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/resume_service.dart';
import '../../config/colors.dart';
import '../../models/resume_analysis_model.dart';
import '../scoring/resume_scoring_screen.dart';
import '../upload/resume_upload_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ResumeService _resumeService = ResumeService();
  ResumeAnalysisModel? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResumeAnalysis();
  }

  Future<void> _loadResumeAnalysis() async {
    try {
      // Get current user ID from AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final analysis = await _resumeService.getResumeAnalysis(user.uid);
      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Abmeldung fehlgeschlagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editProfile() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    
    final nameController = TextEditingController(text: _analysis?.extractedName ?? user?.displayName ?? '');
    final emailController = TextEditingController(text: _analysis?.extractedEmail ?? user?.email ?? '');
    final phoneController = TextEditingController(text: _analysis?.extractedPhone ?? '');
    final addressController = TextEditingController(text: _analysis?.extractedAddress ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Save profile changes to Firestore
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil aktualisiert')),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Abmelden',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  (_analysis?.extractedName?.isNotEmpty == true 
                                      ? _analysis!.extractedName!.substring(0, 1).toUpperCase()
                                      : 'DU'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _analysis?.extractedName ?? (Provider.of<AuthService>(context, listen: false).currentUser?.displayName) ?? 'Dein Profil',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _analysis?.extractedEmail ?? (Provider.of<AuthService>(context, listen: false).currentUser?.email) ?? '',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _editProfile,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Saved Analyses Entry
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
                      title: const Text('Gespeicherte Analysen'),
                      subtitle: const Text('Alle bisherigen Lebenslauf-Analysen ansehen'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openAnalysisList,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Upload Resume Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ResumeUploadScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(_analysis != null ? 'Neuen Lebenslauf hochladen' : 'Lebenslauf hochladen'),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Settings Section
                  _buildSettingsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lebenslauf-Analyse',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Overall Score
            Row(
              children: [
                Expanded(
                  child: _buildScoreItem(
                    'Bewertung',
                    '${_analysis!.score}/100',
                    _getScoreColor(_analysis!.score.toInt()),
                  ),
                ),
                Expanded(
                  child: _buildScoreItem(
                    'Level',
                    _analysis!.experienceLevel,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Skills
            if (_analysis!.skills.isNotEmpty) ...[
              const Text(
                'Erkannte Fähigkeiten:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _analysis!.skills.map((skill) => Chip(
                  label: Text(skill),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  labelStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Improvements
            if (_analysis!.improvements.isNotEmpty) ...[
              const Text(
                'Verbesserungsvorschläge:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ..._analysis!.improvements.map((improvement) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        improvement,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zusammenfassung:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _analysis!.summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Benachrichtigungen',
            subtitle: 'Push-Benachrichtigungen verwalten',
            onTap: () {
              // TODO: Navigate to notifications settings
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Datenschutz',
            subtitle: 'Datenschutzeinstellungen',
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.account_circle_outlined,
            title: 'Account wechseln',
            subtitle: 'Mit Google oder Apple anmelden',
            onTap: () {
              _showAccountOptions();
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'FAQ und Kontakt',
            onTap: () {
              // TODO: Navigate to help
            },
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'Über Linku',
            subtitle: 'Version 1.0.0',
            onTap: () {
              // TODO: Show about dialog
            },
          ),
        ],
      ),
    );
  }

  void _openAnalysisList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _AnalysisListScreen(),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return AppColors.success;
    if (score >= 6) return AppColors.warning;
    return AppColors.error;
  }

  void _showAccountOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account wechseln'),
        content: const Text(
          'Möchten Sie sich mit einem echten Google oder Apple Account anmelden? '
          'Das ermöglicht es Ihnen, Ihre Daten zu synchronisieren und auf mehreren Geräten zu nutzen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signInWithGoogle();
            },
            child: const Text('Mit Google'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signInWithApple();
            },
            child: const Text('Mit Apple'),
          ),
        ],
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erfolgreich mit Google angemeldet!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithApple();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erfolgreich mit Apple angemeldet!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _AnalysisListScreen extends StatelessWidget {
  const _AnalysisListScreen();

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Nicht angemeldet')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Gespeicherte Analysen')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resume_analyses')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Noch keine Analysen'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final score = (m['score'] ?? 0).toString();
              final lvl = (m['experienceLevel'] ?? '').toString();
              final summary = (m['summary'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.insert_chart_outlined),
                title: Text('$score/100  •  $lvl'),
                subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final analysis = ResumeAnalysisModel.fromMap(m);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ResumeScoringScreen(analysis: analysis)));
                },
              );
            },
          );
        },
      ),
    );
  }
}
