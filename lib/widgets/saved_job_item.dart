import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../config/colors.dart';

class SavedJobItem extends StatelessWidget {
  final JobModel job;
  final VoidCallback onRemove;

  const SavedJobItem({
    super.key,
    required this.job,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Company logo placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.grey400,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Job info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Remove button
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Job details
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  job.location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                
                if (job.salary != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.euro_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    job.salary!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            
            // Tags
            if (job.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: job.tags.map((tag) => _buildTag(tag)).toList(),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Footer
            Row(
              children: [
                Text(
                  job.timeAgo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (job.applicantCount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job.applicantText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _applyToJob(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Bewerben'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    Color tagColor;
    Color textColor;
    
    switch (tag.toLowerCase()) {
      case 'remote':
        tagColor = AppColors.remoteTag;
        textColor = Colors.white;
        break;
      case 'praktikum':
      case 'internship':
        tagColor = AppColors.internshipTag;
        textColor = Colors.white;
        break;
      case 'vollzeit':
      case 'fulltime':
        tagColor = AppColors.fulltimeTag;
        textColor = Colors.white;
        break;
      default:
        tagColor = AppColors.grey200;
        textColor = AppColors.textSecondary;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _applyToJob(BuildContext context) async {
    if (job.applicationUrl != null && job.applicationUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(job.applicationUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar(context, 'Link konnte nicht geöffnet werden');
        }
      } catch (e) {
        _showErrorSnackBar(context, 'Fehler beim Öffnen des Links');
      }
    } else {
      _showErrorSnackBar(context, 'Kein Bewerbungslink verfügbar');
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
