import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/colors.dart';
import '../../models/job_model.dart';
import '../../models/application_model.dart';
import '../../models/filter_model.dart';
import '../../services/firestore_service.dart';

class ApplyQueueScreen extends StatefulWidget {
  final List<JobModel> initialJobs; // can be empty; screen will load saved jobs if empty
  const ApplyQueueScreen({super.key, this.initialJobs = const []});

  @override
  State<ApplyQueueScreen> createState() => _ApplyQueueScreenState();
}

class _ApplyQueueScreenState extends State<ApplyQueueScreen> {
  final FirestoreService _fs = FirestoreService();
  List<JobModel> _jobs = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _running = false;
  FilterModel? _filters;
  bool _sortNewest = true;
  final Set<String> _applied = {};
  bool _hideNoUrl = false;
  bool _hideApplied = true;
  int _runOpened = 0; // geöffnete Bewerbungen im aktuellen Lauf
  int _runTotal = 0;  // geplante Bewerbungen im aktuellen Lauf

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (widget.initialJobs.isNotEmpty) {
        _jobs = widget.initialJobs;
      } else {
        _jobs = await _fs.getSavedJobs();
      }
      try {
        _filters = await _fs.getFilters();
      } catch (_) {}
      try {
        final apps = await _fs.getApplications();
        _applied
          ..clear()
          ..addAll(apps.map((a) => a.jobId));
      } catch (_) {}
      _sortJobs();
      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _sortJobs() {
    _jobs.sort((a, b) {
      final ad = a.postedAt;
      final bd = b.postedAt;
      return _sortNewest ? bd.compareTo(ad) : ad.compareTo(bd);
    });
  }

  Future<void> _startApply({int? batchSize}) async {
    if (_running) return;
    final allSelected = _jobs
        .where((j) => _selected.contains(j.id) && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id))
        .toList();
    final toApply = batchSize == null ? allSelected : allSelected.take(batchSize).toList();
    if (toApply.isEmpty) return;
    setState(() {
      _running = true;
      _runOpened = 0;
      _runTotal = toApply.length;
    });
    for (final job in toApply) {
      try {
        final uri = Uri.parse(job.applicationUrl!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(milliseconds: 300));
        final app = ApplicationModel(
          id: '${job.id}_${DateTime.now().millisecondsSinceEpoch}',
          jobId: job.id,
          jobTitle: job.title,
          company: job.company,
          applicationUrl: job.applicationUrl ?? '',
          status: ApplicationStatus.applied,
          applicationDate: DateTime.now(),
        );
        await _fs.createApplication(app);
        _applied.add(job.id);
        _selected.remove(job.id);
      } catch (_) {}
      if (mounted) setState(() => _runOpened++);
    }
    if (!mounted) return;
    setState(() => _running = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bewerbungen geöffnet und gespeichert')));

    final remaining = _jobs
        .where((j) => _selected.contains(j.id) && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id))
        .length;
    if (remaining > 0 && batchSize != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Noch $remaining übrig'),
          action: SnackBarAction(label: 'Weiter', onPressed: () => _startApply(batchSize: batchSize)),
        ),
      );
    }
  }

  Future<void> _confirmAndStart() async {
    if (_selected.isEmpty || _running) return;
    final selectedValid = _jobs
        .where((j) => _selected.contains(j.id) && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id))
        .length;
    final noLinkCount = _jobs.where((j) => _selected.contains(j.id) && (j.applicationUrl ?? '').isEmpty).length;
    final alreadyCount = _jobs.where((j) => _selected.contains(j.id) && _applied.contains(j.id)).length;
    if (selectedValid == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine gültigen Bewerbungslinks in der Auswahl')));
      return;
    }

    int? choice;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bewerbungen öffnen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('$selectedValid werden geöffnet', style: const TextStyle(color: AppColors.ink700)),
              if (noLinkCount > 0) ...[
                const SizedBox(height: 6),
                Text('$noLinkCount ohne Link werden übersprungen', style: const TextStyle(color: AppColors.ink500)),
              ],
              if (alreadyCount > 0) ...[
                const SizedBox(height: 6),
                Text('$alreadyCount bereits beworben werden übersprungen', style: const TextStyle(color: AppColors.ink500)),
              ],
              const SizedBox(height: 16),
              const Text('Batch-Größe', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _choicePill('3', () { choice = 3; Navigator.pop(context); }),
                _choicePill('5', () { choice = 5; Navigator.pop(context); }),
                _choicePill('10', () { choice = 10; Navigator.pop(context); }),
                _choicePill('Alle', () { choice = null; Navigator.pop(context); }),
              ]),
            ],
          ),
        );
      },
    );
    await _startApply(batchSize: choice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Bewerben (Warteschlange)'),
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(_selected.length == _jobs.length ? 'Keine' : 'Alle', style: const TextStyle(fontWeight: FontWeight.w700)),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? const Center(child: Text('Keine gespeicherten Jobs'))
              : Column(
                  children: [
                    _quickSelectBar(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${_selected.length} von ${_visibleJobs().length} sichtbar', style: const TextStyle(color: AppColors.ink500)),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _visibleJobs().length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _queueItem(_visibleJobs()[i]),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty || _running ? null : _confirmAndStart,
              child: Text(_running ? 'Wird geöffnet... (${_runOpened}/${_runTotal})' : 'Jetzt bewerben (${_selected.length})'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickSelectBar() {
    final city = _filters?.location?.split(',').first.trim();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        _pill('Alle', _preselectAll),
        const SizedBox(width: 8),
        _pill('Keine', _preselectNone),
        const SizedBox(width: 8),
        _pill('Remote', _preselectRemote),
        if ((city ?? '').isNotEmpty) ...[
          const SizedBox(width: 8),
          _pill('In ${city!}', _preselectMyCity),
        ],
        const SizedBox(width: 8),
        _pill('Mit Gehalt', _preselectWithSalary),
        const SizedBox(width: 8),
        _togglePill(_sortNewest ? 'Neueste oben' : 'Älteste oben', _toggleSort),
        const SizedBox(width: 8),
        _togglePill(_hideNoUrl ? 'Ohne Link ausblenden ✓' : 'Ohne Link ausblenden', () => setState(() { _hideNoUrl = !_hideNoUrl; })),
        const SizedBox(width: 8),
        _togglePill(_hideApplied ? 'Beworben ausblenden ✓' : 'Beworben ausblenden', () => setState(() { _hideApplied = !_hideApplied; })),
      ]),
    );
  }

  Widget _queueItem(JobModel j) {
    final selected = _selected.contains(j.id);
    final disabled = (j.applicationUrl ?? '').isEmpty || _applied.contains(j.id);
    final city = j.location.split(',').first.trim();
    final pills = <String>[];
    if ((j.workType.toLowerCase().contains('remote')) || (j.remotePercentage is num && (j.remotePercentage as num) > 0)) pills.add('Remote');
    if (j.jobType.isNotEmpty) pills.add(j.jobType);
    if ((j.experienceLevel ?? '').isNotEmpty) pills.add(j.experienceLevel!);
    if (_applied.contains(j.id)) pills.add('Beworben');
    return Card(
      child: InkWell(
        onTap: disabled ? null : () => setState(() => selected ? _selected.remove(j.id) : _selected.add(j.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            leading: Checkbox(
              value: selected,
              onChanged: disabled ? null : (_) => setState(() => selected ? _selected.remove(j.id) : _selected.add(j.id)),
            ),
            title: Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${j.company} • $city', maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: pills.take(3).map((t) => _miniPill(t)).toList()),
            ]),
            trailing: _applied.contains(j.id)
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ((j.applicationUrl ?? '').isEmpty ? const Icon(Icons.link_off, color: AppColors.ink400) : const Icon(Icons.open_in_new)),
          ),
        ),
      ),
    );
  }

  Widget _miniPill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder(side: BorderSide(color: AppColors.ink200))),
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink700)),
    );
  }

  Widget _pill(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder(side: BorderSide(color: AppColors.ink200))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink700)),
      ),
    );
  }

  Widget _togglePill(String label, VoidCallback onTap) => _pill(label, onTap);

  void _toggleAll() {
    setState(() {
      final visibleIds = _visibleJobs()
          .where((j) => (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id))
          .map((j) => j.id)
          .toSet();
      if (visibleIds.isNotEmpty && visibleIds.every((id) => _selected.contains(id))) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(visibleIds);
      }
    });
  }

  void _preselectAll() => setState(() {
        _selected
          ..clear()
          ..addAll(_visibleJobs()
              .where((j) => (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id))
              .map((j) => j.id));
      });

  void _preselectNone() => setState(() => _selected.clear());

  void _preselectRemote() => setState(() {
        _selected
          ..clear()
          ..addAll(_visibleJobs().where((j) {
            final wt = j.workType.toLowerCase();
            final ok = wt.contains('remote') || (j.remotePercentage is num && (j.remotePercentage as num) > 0);
            return ok && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id);
          }).map((j) => j.id));
      });

  void _preselectMyCity() => setState(() {
        final city = (_filters?.location ?? '').split(',').first.trim().toLowerCase();
        _selected
          ..clear()
          ..addAll(_visibleJobs().where((j) {
            final match = j.location.split(',').first.trim().toLowerCase() == city;
            return match && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id);
          }).map((j) => j.id));
      });

  void _preselectWithSalary() => setState(() {
        _selected
          ..clear()
          ..addAll(_visibleJobs().where((j) => (j.salary ?? '').toString().trim().isNotEmpty && (j.applicationUrl ?? '').isNotEmpty && !_applied.contains(j.id)).map((j) => j.id));
      });

  void _toggleSort() => setState(() {
        _sortNewest = !_sortNewest;
        _sortJobs();
      });

  Widget _choicePill(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder(side: BorderSide(color: AppColors.ink200))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink700)),
      ),
    );
  }

  List<JobModel> _visibleJobs() {
    return _jobs.where((j) {
      if (_hideNoUrl && (j.applicationUrl ?? '').isEmpty) return false;
      if (_hideApplied && _applied.contains(j.id)) return false;
      return true;
    }).toList();
  }
}


