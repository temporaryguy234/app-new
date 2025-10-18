import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../config/colors.dart';

class JobCard extends StatefulWidget {
  final JobModel job;
  final VoidCallback? onApply;

  const JobCard({
    super.key,
    required this.job,
    this.onApply,
  });

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with company logo and bookmark
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Company logo placeholder
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.grey400,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Company name and job title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bookmark icon
                Icon(
                  Icons.bookmark_border,
                  color: AppColors.grey400,
                ),
              ],
            ),
          ),
          
          // Job details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
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
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Salary
                if (job.salary != null) ...[
                  Row(
                    children: [
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
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Tags
                if (job.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: job.tags.map((tag) => _buildTag(tag)).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Description
                if (job.description != null) ...[
                  Text(
                    job.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Expandable details
                if (_expanded) ...[
                  if (job.postalCode != null && job.postalCode!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.pin_drop, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('PLZ: ${job.postalCode}', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (job.requirements != null && job.requirements!.isNotEmpty) ...[
                    Text('Anforderungen:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: job.requirements!.map((req) => Chip(
                        label: Text(req, style: TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                
                // Expand/Collapse button
                if (job.description != null || (job.requirements != null && job.requirements!.isNotEmpty))
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Weniger anzeigen' : 'Mehr anzeigen'),
                  ),
                
                // Footer info
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
                  ],
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Apply button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () async {
                // Save job first
                widget.onApply?.call();
                // Then apply
                await _applyToJob(context);
              },
              child: const Text('Bewerben'),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _applyToJob(BuildContext context) async {
    if (job.applicationUrl != null && job.applicationUrl!.isNotEmpty) {
      try {
        // Show confirmation dialog
        final shouldApply = await _showApplicationDialog(context);
        if (shouldApply == true) {
          // Launch application URL
          final uri = Uri.parse(job.applicationUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showErrorSnackBar(context, 'Link konnte nicht geöffnet werden');
          }
        }
      } catch (e) {
        _showErrorSnackBar(context, 'Fehler beim Öffnen des Links');
      }
    } else {
      _showErrorSnackBar(context, 'Kein Bewerbungslink verfügbar');
    }
  }

  Future<bool?> _showApplicationDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bewerbung starten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchten Sie sich bei ${job.company} bewerben?'),
            const SizedBox(height: 16),
            const Text(
              'Ihre Bewerbungsdaten werden automatisch übertragen:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• Persönliche Daten aus Ihrem Profil'),
            const Text('• Lebenslauf wird automatisch hochgeladen'),
            const Text('• Anschreiben wird vorausgefüllt'),
            const Text('• Kontaktdaten werden übertragen'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Jetzt bewerben'),
          ),
        ],
      ),
    );
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
