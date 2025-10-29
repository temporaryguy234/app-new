import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/resume_service.dart';
import '../../config/colors.dart';
import '../../models/resume_analysis_model.dart';
import '../scoring/resume_scoring_screen.dart';
import '../upload/resume_upload_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cv_export_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ResumeService _resumeService = ResumeService();
  ResumeAnalysisModel? _analysis;
  bool _isLoading = true;
  bool _isPremium = false;
  String? _lastCvUrl;

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
      // read premium flag
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _isPremium = (userDoc.data()?['premium'] == true);
      _lastCvUrl = userDoc.data()?['cvExport']?['url'] as String?;
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

  String _displayName() {
    final auth = Provider.of<AuthService>(context, listen: false).currentUser;
    final fromAnalysis = (_analysis?.name ?? '').trim();
    if (fromAnalysis.isNotEmpty) return fromAnalysis;
    final fromAuth = (auth?.displayName ?? '').trim();
    if (fromAuth.isNotEmpty) return fromAuth;
    final emailPart = (auth?.email ?? '').split('@').first;
    return emailPart.isNotEmpty ? emailPart : 'Dein Profil';
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // Clean white header to match app style
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Profile picture with edit icon
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: _analysis?.profilePictureUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          _analysis!.profilePictureUrl!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            size: 50,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 50,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                            // Edit icon
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // User name
                        Text(
                          _displayName(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Verification badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, color: AppColors.primary, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verifiziert',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.black),
                  onPressed: _signOut,
                  tooltip: 'Abmelden',
                ),
              ],
            ),
            // Custom tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  tabs: const [
                    Tab(text: 'Erhalte mehr'),
                    Tab(text: 'Sicherheit'),
                    Tab(text: 'Mein Konto'),
                  ],
                ),
              ),
            ),
            // Tab content
            SliverFillRemaining(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _tabErhalteMehr(),
                        _tabSicherheit(),
                        _tabMeinKonto(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabErhalteMehr() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium card - Hinge style
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF1E3A8A)], // primaryDark
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPremium ? 'Premium aktiv' : 'Premium freischalten',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '1‑Klick‑Bewerben, CV‑Export, Specials unbegrenzt',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPremium ? () => _showSnack('Premium bereits aktiv') : _mockUpgrade,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith((states) => Colors.white),
                        foregroundColor: MaterialStateProperty.all(AppColors.primary),
                        overlayColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.08)),
                        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        elevation: MaterialStateProperty.all(0),
                      ),
                      child: Text(
                        _isPremium ? 'Aktiv' : 'Jetzt upgraden',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // CV Export card - more engaging
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isPremium ? _exportCv : () => _showSnack('CV‑Export ist Premium'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CV exportieren (PDF)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastCvUrl == null 
                                  ? 'Schönes PDF aus deiner Analyse' 
                                  : 'Letzter Export verfügbar',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isPremium ? Icons.chevron_right : Icons.lock_outline,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabSicherheit() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSettingsSection(),
    );
  }

  Widget _tabMeinKonto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
              title: const Text('Gespeicherte Analysen'),
              subtitle: const Text('Alle bisherigen Lebenslauf-Analysen ansehen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAnalysisList,
            ),
          ),
          const SizedBox(height: 16),
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
        ],
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

  Future<void> _mockUpgrade() async {
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'premium': true}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() { _isPremium = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium aktiviert'), backgroundColor: AppColors.success));
    } catch (_) {}
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

  Future<void> _exportCv() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    if (_analysis == null) {
      _showSnack('Keine Analyse gefunden');
      return;
    }
    try {
      _showSnack('Export wird erstellt...');
      final url = await CvExportService().exportImprovedCv(_analysis!);
      if (!mounted) return;
      setState(() { _lastCvUrl = url; });
      _showSnack('CV exportiert');
    } catch (e) {
      _showSnack('Fehler beim Export: $e');
    }
  }

  void _showSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
            // Avoid composite index requirement; sort client-side
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList();
          // Sort by createdAt desc if present
          docs.sort((a, b) {
            final ma = a.data() as Map<String, dynamic>;
            final mb = b.data() as Map<String, dynamic>;
            final ta = ma['createdAt'];
            final tb = mb['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
          if (docs.isEmpty) return const Center(child: Text('Noch keine Analysen'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final raw = docs[i].data() as Map<String, dynamic>;
              final m = {
                ...raw,
                'id': raw['id'] ?? docs[i].id, // ensure id present for model
              };
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

// Custom tab bar delegate for SliverPersistentHeader
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
