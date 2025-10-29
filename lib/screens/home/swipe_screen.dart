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
import '../../models/filter_model.dart';
import '../../services/premium_service.dart';
// import '../main/main_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final JobService _jobService = JobService();
  final FirestoreService _firestoreService = FirestoreService();
  final CardSwiperController _swiperController = CardSwiperController();
  final PremiumService _premium = PremiumService();
  
  List<JobModel> _jobs = [];
  bool _isLoading = false;
  int _currentIndex = 0;
  List<JobModel> _rejectedJobs = [];
  List<JobModel> _savedJobs = [];
  bool _swipeDisabled = false;
  bool _isPremium = false;
  final TextEditingController _locationCtrl = TextEditingController();
  double _distanceKm = 50;
  // Simple filter state (mirrors Firestore filters)
  final Set<String> _selectedJobTypes = <String>{};
  double _remotePct = 0; // persisted value
  String _remoteMode = 'Vor Ort'; // UI: 'Remote' | 'Hybrid' | 'Vor Ort'
  double? _minSalary;
  double? _maxSalary;

  @override
  void initState() {
    super.initState();
    _refreshPremiumState();
    _loadJobs();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPremiumState() async {
    final canSwipe = await _premium.canSwipe();
    final isPrem = await _premium.isPremium();
    if (!mounted) return;
    setState(() {
      _swipeDisabled = !canSwipe;
      _isPremium = isPrem;
    });
  }

  Future<void> _handleRefresh() async {
    if (!_isPremium) {
      _showPremiumDialog();
      return;
    }
    
    await _loadJobs(forceRefresh: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jobs aktualisiert!')),
      );
    }
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Feature'),
        content: const Text('Job-Refresh ist nur für Premium-Nutzer verfügbar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to premium screen
              Navigator.pushNamed(context, '/profile');
            },
            child: const Text('Premium ansehen'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadJobs({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }

      final resumeService = ResumeService();
      final jobs = await resumeService.loadJobsForUser(user.uid, forceRefresh: forceRefresh);
      setState(() { _jobs = jobs; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSwipe(int? previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    if (_swipeDisabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tageslimit erreicht – Premium schaltet unbegrenzt frei')),
        );
      }
      return;
  }

    if (previousIndex != null && previousIndex < _jobs.length) {
      if (direction == CardSwiperDirection.left) {
        _rejectJob(_jobs[previousIndex]);
      } else if (direction == CardSwiperDirection.right) {
        _saveJob(_jobs[previousIndex]);
      }
    }

    await _premium.recordSwipe();
    final canSwipe = await _premium.canSwipe();
    
    setState(() {
      _currentIndex = currentIndex ?? 0;
      _swipeDisabled = !canSwipe;
    });

    if (_swipeDisabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tageslimit erreicht – Premium schaltet unbegrenzt frei')),
      );
    }
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

  Future<void> _saveJob(JobModel job) async {
    try {
      // enforce daily save limit for free
      final canSave = await _premium.canSave();
      if (!canSave) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tageslimit erreicht: Nur 7 Speichern pro Tag in Free'),
            ),
          );
        }
        return;
      }
      await _firestoreService.saveJob(job);
      await _premium.recordSave();
      setState(() {
        _savedJobs.add(job);
      });
      if (!mounted) return;
      // Info-Toast: gespeichert
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${job.title} gespeichert'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
      ),
    );
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

  Future<void> _openFilterSheet() async {
    // preload saved filters
    final fs = FirestoreService();
    final f = await fs.getFilters();
    if (f != null) {
      _locationCtrl.text = f.location ?? _locationCtrl.text;
      _distanceKm = f.maxDistance ?? _distanceKm;
      _selectedJobTypes
        ..clear()
        ..addAll(f.jobTypes);
      _remotePct = f.minRemotePercentage ?? _remotePct;
      // map persisted percentage to categorical mode
      if (_remotePct >= 80) {
        _remoteMode = 'Remote';
      } else if (_remotePct >= 20) {
        _remoteMode = 'Hybrid';
      } else {
        _remoteMode = 'Vor Ort';
      }
      _minSalary = f.minSalary;
      _maxSalary = f.maxSalary;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return StatefulBuilder(builder: (context, setModal) {
              return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tune),
                      SizedBox(width: 8),
                      Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Stadt',
                      hintText: 'z. B. Aschaffenburg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Max. Entfernung: ${_distanceKm.toInt()} km'),
                  Slider(
                    value: _distanceKm,
                    min: 5,
                    max: 200,
                    divisions: 39,
                    onChanged: (v) => setModal(() => _distanceKm = v),
                  ),
                  const SizedBox(height: 16),

                  // Jobtyp
                  const Text('Stellentyp', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Vollzeit','Teilzeit','Praktikum','Werkstudent','Minijob']
                        .map((type) => FilterChip(
                              label: Text(type),
                              selected: _selectedJobTypes.contains(type),
                              onSelected: (sel) => setModal(() {
                                sel ? _selectedJobTypes.add(type) : _selectedJobTypes.remove(type);
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Remote
                  const Text('Arbeitsmodus', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Remote','Hybrid','Vor Ort'].map((m) => ChoiceChip(
                      label: Text(m),
                      selected: _remoteMode == m,
                      onSelected: (_) => setModal(() => _remoteMode = m),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Gehalt
                  const Text('Gehalt', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _minSalary?.toInt().toString(),
                          decoration: const InputDecoration(labelText: 'Min. Gehalt', suffixText: '€'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setModal(() => _minSalary = double.tryParse(v)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxSalary?.toInt().toString(),
                          decoration: const InputDecoration(labelText: 'Max. Gehalt', suffixText: '€'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setModal(() => _maxSalary = double.tryParse(v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final fs = FirestoreService();
                        final existing = await fs.getFilters();
                        // map categorical mode to percentage for persistence
                        final modePct = _remoteMode == 'Remote' ? 100.0 : _remoteMode == 'Hybrid' ? 50.0 : 0.0;
                        final next = (existing ?? FilterModel()).copyWith(
                          location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
                          maxDistance: _distanceKm,
                          jobTypes: _selectedJobTypes.toList(),
                          minRemotePercentage: modePct,
                          minSalary: _minSalary,
                          maxSalary: _maxSalary,
                        );
                        await fs.saveFilters(next);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        _loadJobs();
                      },
                      child: const Text('Filter anwenden'),
                    ),
                  ),
                ],
              ),
            );
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Linku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text('Noch keine passenden Jobs', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Filter prüfen oder Standort (PLZ/Stadt) anpassen', style: TextStyle(color: AppColors.textTertiary)),
                      const SizedBox(height: 24),
                      ElevatedButton(onPressed: _loadJobs, child: const Text('Erneut suchen')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_rejectedJobs.isNotEmpty || _savedJobs.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(icon: const Icon(Icons.undo), onPressed: _undoLastAction, tooltip: 'Rückgängig'),
                      ),
                    Expanded(
                      child: CardSwiper(
                        controller: _swiperController,
                        cardsCount: _jobs.length,
                        isLoop: false,
                        isDisabled: _swipeDisabled,
                        padding: EdgeInsets.zero,
                        onSwipe: _onSwipe,
                        cardBuilder: (context, index) {
                          if (index >= _jobs.length) return null;
                          return JobCard(
                            job: _jobs[index],
                            isPremium: _isPremium,
                            onApply: (job) => _saveJob(job),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
