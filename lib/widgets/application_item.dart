import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/application_model.dart';
import '../config/colors.dart';

class ApplicationItem extends StatelessWidget {
  final ApplicationModel application;
  final Function(ApplicationStatus) onStatusChanged;
  final VoidCallback onDelete;

  const ApplicationItem({
    super.key,
    required this.application,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with company and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application.company,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(application.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(application.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    application.statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(application.status),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Application details
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  application.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.link,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Bewerbungsseite',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            
            // Notes if available
            if (application.notes != null && application.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        application.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                // Status dropdown
                Expanded(
                  child: DropdownButtonFormField<ApplicationStatus>(
                    value: application.status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    items: ApplicationStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_getStatusText(status)),
                      );
                    }).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        onStatusChanged(newStatus);
                      }
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // View application button
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openApplicationUrl(context),
                  tooltip: 'Bewerbung ansehen',
                ),
                
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteDialog(context),
                  tooltip: 'Löschen',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return Colors.blue;
      case ApplicationStatus.interview:
        return Colors.orange;
      case ApplicationStatus.offer:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.accepted:
        return Colors.green;
      case ApplicationStatus.withdrawn:
        return Colors.grey;
    }
  }

  Future<void> _openApplicationUrl(BuildContext context) async {
    try {
      final uri = Uri.parse(application.applicationUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar(context, 'Link konnte nicht geöffnet werden');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Fehler beim Öffnen des Links');
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bewerbung löschen'),
        content: Text('Möchten Sie die Bewerbung bei ${application.company} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            child: const Text('Löschen'),
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

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
