import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../services/job_service.dart';
import '../../services/firestore_service.dart';
import '../../services/resume_service.dart';
import '../../services/auth_service.dart';
import '../../models/job_model.dart';
import '../../config/colors.dart';
import '../../widgets/job_card.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final JobService _jobService = JobService();
  final FirestoreService _firestoreService = FirestoreService();
  final CardSwiperController _swiperController = CardSwiperController();
  
  List<JobModel> _jobs = [];
  bool _isLoading = false;
  int _currentIndex = 0;
  List<JobModel> _rejectedJobs = [];
  List<JobModel> _savedJobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }

      final resumeService = ResumeService();
      final analysis = await resumeService.getResumeAnalysis(user.uid);
      if (analysis == null) { setState(() => _isLoading = false); return; }

      final jobs = await resumeService.findJobsForAnalysis(analysis);
      setState(() { _jobs = jobs; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSwipe(int? previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex != null && previousIndex < _jobs.length) {
      if (direction == CardSwiperDirection.left) {
        _rejectJob(_jobs[previousIndex]);
      } else if (direction == CardSwiperDirection.right) {
        _saveJob(_jobs[previousIndex]);
      }
    }
    
    setState(() {
      _currentIndex = currentIndex ?? 0;
    });
  }

  void _rejectJob(JobModel job) async {
    try {
      await _firestoreService.saveRejectedJob(job);
      setState(() {
        _rejectedJobs.add(job);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${job.title} abgelehnt'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _saveJob(JobModel job) async {
    try {
      await _firestoreService.saveJob(job);
      setState(() {
        _savedJobs.add(job);
      });
      
      // Sofort zum Gespeichert-Tab wechseln
      if (mounted) {
        // Navigation zum Gespeichert-Tab (Index 1)
        final mainScreen = context.findAncestorStateOfType<_MainScreenState>();
        if (mainScreen != null) {
          mainScreen.setState(() {
            mainScreen._currentIndex = 1; // Gespeichert-Tab
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${job.title} gespeichert'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _undoLastAction() async {
    if (_currentIndex > 0 && (_rejectedJobs.isNotEmpty || _savedJobs.isNotEmpty)) {
      JobModel? lastJob;
      String? lastAction;
      
      // Get the last action
      if (_savedJobs.isNotEmpty) {
        lastJob = _savedJobs.removeLast();
        lastAction = 'saved';
      } else if (_rejectedJobs.isNotEmpty) {
        lastJob = _rejectedJobs.removeLast();
        lastAction = 'rejected';
      }
      
      if (lastJob != null) {
        // Remove from Firestore
        if (lastAction == 'saved') {
          await _firestoreService.removeJob(lastJob.id);
        } else {
          // For rejected jobs, we don't need to do anything special
        }
        
        // Add job back to the beginning of the list
        setState(() {
          _jobs.insert(0, lastJob!);
          _currentIndex = 0;
        });
        
        // Reset swiper to show the first card
        // Note: CardSwiperController doesn't have a move method
        // The swiper will automatically show the first card when _currentIndex is 0
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lastJob.title} rückgängig gemacht'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Linku'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine passenden Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Filter prüfen oder Standort (PLZ/Stadt) anpassen',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadJobs,
                        child: const Text('Erneut suchen'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Optional undo button only
                    if (_rejectedJobs.isNotEmpty || _savedJobs.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.undo),
                          onPressed: _undoLastAction,
                          tooltip: 'Rückgängig',
                        ),
                      ),
                    
                    // Swipe cards
                    Expanded(
                      child: CardSwiper(
                        controller: _swiperController,
                        cardsCount: _jobs.length,
                        isLoop: false,
                        // Verhindere vertikale Swipes (nur links/rechts zulassen)
                        // Einige Versionen unterstützen allowedDirections; falls nicht vorhanden, wird diese Zeile ignoriert.
                        allowedDirections: const [
                          CardSwiperDirection.left,
                          CardSwiperDirection.right,
                        ],
                        // Blende den eingebauten Zähler ("1 von N") aus, wenn die Version dies unterstützt
                        isNumber: false,
                        onSwipe: _onSwipe,
                        cardBuilder: (context, index) {
                          if (index >= _jobs.length) return null;
                          return JobCard(
                            job: _jobs[index],
                            onApply: () => _saveJob(_jobs[index]),
                          );
                        },
                      ),
                    ),
                    
                    // Action buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Reject button
                          FloatingActionButton(
                            heroTag: 'reject',
                            onPressed: () {
                              _swiperController.swipeLeft();
                            },
                            backgroundColor: AppColors.error,
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                          
                          // Save button
                          FloatingActionButton(
                            heroTag: 'save',
                            onPressed: () {
                              _swiperController.swipeRight();
                            },
                            backgroundColor: AppColors.success,
                            child: const Icon(Icons.favorite, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
