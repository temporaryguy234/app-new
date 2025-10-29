import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../config/colors.dart';
import '../services/premium_service.dart';

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
                _companyLogo(job),
                
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
            
            // Job details (meta rows)
            _meta(Icons.place_outlined, job.location.split(',').first.trim()),
            if ((job.salary ?? '').isNotEmpty) _meta(Icons.payments_outlined, job.salary!),
            
            // Tags
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((job.workType.toLowerCase().contains('remote')) || ((job.remotePercentage ?? '').toString().isNotEmpty)) _pill('Remote'),
                if (job.jobType.isNotEmpty) _pill(job.jobType),
                if ((job.experienceLevel ?? '').isNotEmpty) _pill(job.experienceLevel!),
                ...job.tags.take(2).map((t) => _pill(t)),
              ],
            ),
            
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

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink700)),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.ink400),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.ink500), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _companyLogo(JobModel job) {
    final name = job.company.trim();
    final initials = name.isEmpty ? '•' : name.split(' ').map((w)=>w.isNotEmpty?w[0].toUpperCase():'').take(2).join('');
    final logo = job.companyLogo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (logo != null && logo.isNotEmpty)
          ? Image.network(logo, width: 40, height: 40, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsBox(initials))
          : _initialsBox(initials),
    );
  }

  Widget _initialsBox(String initials) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
    );
  }

  Future<void> _applyToJob(BuildContext context) async {
    if (job.applicationUrl != null && job.applicationUrl!.isNotEmpty) {
      try {
        final isPrem = await PremiumService().isPremium();
        final uri = Uri.parse(job.applicationUrl!);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) _showErrorSnackBar(context, 'Link konnte nicht geöffnet werden');
        else if (!isPrem) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto‑Bewerben ist Premium. Seite wurde geöffnet.')),
          );
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
