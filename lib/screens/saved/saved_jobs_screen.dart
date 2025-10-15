import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/job_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/saved_job_item.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<JobModel> _savedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    setState(() => _isLoading = true);
    
    try {
      final jobs = await _firestoreService.getSavedJobs();
      setState(() {
        _savedJobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeJob(JobModel job) async {
    try {
      await _firestoreService.removeJob(job.id);
      setState(() {
        _savedJobs.removeWhere((j) => j.id == job.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${job.title} entfernt'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Entfernen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gespeicherte Jobs'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _savedJobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine gespeicherten Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Swipe Jobs nach rechts um sie zu speichern',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedJobs.length,
                  itemBuilder: (context, index) {
                    final job = _savedJobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SavedJobItem(
                        job: job,
                        onRemove: () => _removeJob(job),
                      ),
                    );
                  },
                ),
    );
  }
}
