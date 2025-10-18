import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/job_model.dart';
import '../../services/resume_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
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
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) { setState(() => _loading = false); return; }
      final analysis = await _resumeService.getResumeAnalysis(user.uid);
      if (analysis == null) { setState(() => _loading = false); return; }

      // Specials: breiter suchen (ohne PLZ, nur Stadt/Land)
      final broader = analysis.copyWith(postalCode: '');
      var jobs = await _resumeService.findJobsForAnalysis(broader);
      if (jobs.length < 15) {
        // leichte Erweiterung über generische Titel
        final more = await _resumeService.findJobsForAnalysis(
          analysis,
        );
        jobs.addAll(more);
        final seen = <String>{};
        jobs = jobs.where((j) => seen.add('${(j.applicationUrl ?? '').toLowerCase()}|${j.title.toLowerCase()}')).toList();
      }
      setState(() { _jobs = jobs; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Specials'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(child: Text('Keine Empfehlungen verfügbar'))
              : ListView.builder(
                  itemCount: _jobs.length,
                  itemBuilder: (_, i) => JobCard(job: _jobs[i]),
                ),
    );
  }
}


