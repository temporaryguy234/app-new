import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../widgets/list_skeleton.dart';
import '../../models/application_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/application_item.dart';
import '../../widgets/primitives/filter_chip_pill.dart';
import '../../widgets/primitives/empty_state.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<ApplicationModel> _applications = [];
  bool _isLoading = true;
  ApplicationStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    
    try {
      final applications = await _firestoreService.getApplications();
      setState(() {
        _applications = applications;
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

  Future<void> _updateApplicationStatus(ApplicationModel application, ApplicationStatus newStatus) async {
    try {
      await _firestoreService.updateApplicationStatus(application.id, newStatus);
      setState(() {
        final index = _applications.indexWhere((a) => a.id == application.id);
        if (index != -1) {
          _applications[index] = application.copyWith(status: newStatus);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status aktualisiert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Aktualisieren: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteApplication(ApplicationModel application) async {
    try {
      await _firestoreService.deleteApplication(application.id);
      setState(() {
        _applications.removeWhere((a) => a.id == application.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bewerbung entfernt'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<ApplicationModel> get _filteredApplications {
    if (_selectedStatus == null) return _applications;
    return _applications.where((app) => app.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Meine Bewerbungen'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<ApplicationStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Alle'),
              ),
              ...ApplicationStatus.values.map((status) => PopupMenuItem(
                value: status,
                child: Text(_getStatusText(status)),
              )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeleton()
          : _filteredApplications.isEmpty
              ? EmptyState(
                  icon: Icons.work_outline,
                  title: _selectedStatus == null ? 'Noch keine Bewerbungen' : 'Keine Bewerbungen mit diesem Status',
                  subtitle: _selectedStatus == null
                      ? 'Bewerben Sie sich auf Jobs um den Status zu verfolgen'
                      : 'Wählen Sie einen anderen Filter',
                )
              : Column(
                  children: [
                    // Status filter chips
                    if (_selectedStatus != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        FilterChipPill(
                          icon: Icons.filter_alt,
                          label: 'Filter: ${_getStatusText(_selectedStatus!)}',
                          onTap: () => setState(() => _selectedStatus = null),
                        ),
                      ]),
                      ),
                    
                    // Applications list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredApplications.length,
                        itemBuilder: (context, index) {
                          final application = _filteredApplications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ApplicationItem(
                              application: application,
                              onStatusChanged: (newStatus) => _updateApplicationStatus(application, newStatus),
                              onDelete: () => _deleteApplication(application),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return 'Beworben';
      case ApplicationStatus.interview:
        return 'Interview';
      case ApplicationStatus.offer:
        return 'Angebot';
      case ApplicationStatus.rejected:
        return 'Abgelehnt';
      case ApplicationStatus.accepted:
        return 'Angenommen';
      case ApplicationStatus.withdrawn:
        return 'Zurückgezogen';
    }
  }
}
