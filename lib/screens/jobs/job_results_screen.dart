import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/job_model.dart';
import '../../config/colors.dart';

class JobResultsScreen extends StatelessWidget {
  final List<JobModel> jobs;
  
  const JobResultsScreen({super.key, required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${jobs.length} Jobs gefunden'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter implementieren
            },
          ),
        ],
      ),
      body: jobs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Keine passenden Jobs gefunden'),
                  SizedBox(height: 8),
                  Text('Versuche andere Suchbegriffe oder erweitere deine Fähigkeiten'),
                ],
              ),
            )
          : Column(
              children: [
                // Header mit Anzahl
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    '${jobs.length} passende Jobs in deiner Nähe gefunden',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Job-Liste
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () async {
                            final url = job.applicationUrl;
                            if (url != null && url.isNotEmpty) {
                              await launchUrl(
                                Uri.parse(url), 
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Titel
                                Text(
                                  job.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Company & Location
                                Row(
                                  children: [
                                    Icon(Icons.business, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(job.company, style: TextStyle(color: AppColors.textSecondary)),
                                    const SizedBox(width: 16),
                                    Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(job.location, style: TextStyle(color: AppColors.textSecondary)),
                                  ],
                                ),
                                
                                // Salary
                                if (job.salary != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.euro, size: 16, color: AppColors.success),
                                      const SizedBox(width: 4),
                                      Text(job.salary!, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                                
                                // Tags
                                if (job.tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: job.tags.map((tag) => Chip(
                                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      labelStyle: TextStyle(color: AppColors.primary, fontSize: 12),
                                    )).toList(),
                                  ),
                                ],
                                
                                // Apply Button
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () async {
                                        final url = job.applicationUrl;
                                        if (url != null && url.isNotEmpty) {
                                          await launchUrl(
                                            Uri.parse(url), 
                                            mode: LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('Bewerben'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
