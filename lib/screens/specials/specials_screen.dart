import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/resume_service.dart';
import '../../services/auth_service.dart';
import '../../models/job_model.dart';
import '../../config/colors.dart';
import '../../widgets/job_card.dart';

class SpecialsScreen extends StatefulWidget {
  const SpecialsScreen({super.key});

  @override
  State<SpecialsScreen> createState() => _SpecialsScreenState();
}

class _SpecialsScreenState extends State<SpecialsScreen> {
  final _resumeService = ResumeService();
  List<JobModel> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSpecials();
  }

  Future<void> _loadSpecials() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) { 
        setState(() => _loading = false); 
        return; 
      }

      final analysis = await _resumeService.getResumeAnalysis(user.uid);
      if (analysis == null) { 
        setState(() => _loading = false); 
        return; 
      }

      // Erweiterte Suche ohne PLZ-Beschränkung für mehr Vielfalt
      final location = analysis.location.split(',').first; // Nur Stadt, keine PLZ
      final query = _buildSpecialsQuery(analysis);
      
      print('⭐ Specials Query: $query');
      print('📍 Location: $location');
      
      final jobs = await _resumeService.findJobsForAnalysis(analysis);
      
      // Zusätzliche verwandte Titel für mehr Abdeckung
      final relatedTitles = _getRelatedTitles(analysis);
      for (final title in relatedTitles.take(2)) {
        final more = await _resumeService.findJobsForAnalysis(analysis);
        _jobs.addAll(more);
      }
      
      // Deduplizieren
      final seen = <String>{};
      _jobs = jobs.where((j) => seen.add('${(j.applicationUrl ?? '').toLowerCase()}|${j.title.toLowerCase()}')).toList();
      
      setState(() { 
        _jobs = _jobs; 
        _loading = false; 
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Specials: $e')),
        );
      }
    }
  }

  String _buildSpecialsQuery(analysis) {
    final titles = <String>{};
    
    // Basis-Titel aus Skills
    for (final s in analysis.skills) {
      final t = s.toLowerCase();
      if (t.contains('data') || t.contains('analys')) {
        titles.addAll({'data scientist', 'business intelligence', 'analytics engineer'});
      }
      if (t.contains('python')) {
        titles.addAll({'python engineer', 'machine learning engineer', 'data engineer'});
      }
      if (t.contains('javascript') || t.contains('react')) {
        titles.addAll({'frontend engineer', 'full stack developer', 'web developer'});
      }
      if (t.contains('java')) {
        titles.addAll({'java engineer', 'backend engineer', 'software architect'});
      }
      if (t.contains('cloud') || t.contains('aws')) {
        titles.addAll({'cloud engineer', 'devops engineer', 'platform engineer'});
      }
    }
    
    // Verwandte Titel hinzufügen
    titles.addAll({'software engineer', 'developer', 'tech lead', 'senior developer'});
    
    final top = titles.take(8).map((t) => t.contains(' ') ? '"$t"' : t).toList();
    return top.isEmpty ? '"software engineer"' : '(${top.join(' OR ')})';
  }

  List<String> _getRelatedTitles(analysis) {
    final related = <String>[];
    
    // Ähnliche Jobtitel basierend auf Erfahrung
    switch (analysis.experienceLevel) {
      case 'entry':
        related.addAll(['junior developer', 'graduate engineer', 'trainee']);
        break;
      case 'mid':
        related.addAll(['mid-level engineer', 'software developer', 'tech specialist']);
        break;
      case 'senior':
        related.addAll(['senior engineer', 'tech lead', 'principal developer']);
        break;
      case 'expert':
        related.addAll(['staff engineer', 'architect', 'engineering manager']);
        break;
    }
    
    return related;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('⭐ Specials'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSpecials,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Specials verfügbar',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lade deinen Lebenslauf hoch für personalisierte Empfehlungen',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadSpecials,
                        child: const Text('Erneut laden'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        '${_jobs.length} spezielle Empfehlungen für dich',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Job-Liste
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          return JobCard(
                            job: job,
                            onApply: () {
                              // Job speichern (könnte hier implementiert werden)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${job.title} gespeichert')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
