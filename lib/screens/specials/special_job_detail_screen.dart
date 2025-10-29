import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/job_model.dart';
import '../../services/premium_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/colors.dart';

class SpecialJobDetailScreen extends StatelessWidget {
  final JobModel job;
  const SpecialJobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with blurred background
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(left: 8, top: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred background image
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Image.network(
                      _backgroundImageUrlForJob(job),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.surface),
                    ),
                  ),
                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // City chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                job.location.split(',').first.trim(),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Job title
                        Text(
                          job.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key fact chips
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _chips(job),
                ),
                // Kurzprofil card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _lead(job),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          ..._summaryBullets(job).map((b) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(child: Text(b, maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Structured sections
                _buildSectionStatic('Aufgaben', job.responsibilities.isNotEmpty ? job.responsibilities : _bulletsFrom(job.description)),
                _buildSectionStatic('Dein Profil', job.requirements),
                _buildSectionStatic('Benefits', job.benefits),
                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton(
          onPressed: () async {
            final premium = PremiumService();
            final can = await premium.canUseSpecials();
            if (!can) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Premium erforderlich'),
                    content: const Text('Du hast die Specials diese Woche bereits genutzt. Für weitere Bewerbungen brauchst du Premium.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Später')),
                    ],
                  ),
                );
              }
              return;
            }
            await premium.recordSpecialsUse();
            final url = job.applicationUrl;
            if (url != null && url.isNotEmpty) {
              try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
            }
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Stern einsetzen & bewerben', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // Helper methods
  String _short(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max - 1)}…';
  }

  String _backgroundImageUrlForJob(JobModel j) {
    final key = _industryKeyForJob(j);
    switch (key) {
      case 'office':
        return 'https://images.unsplash.com/photo-1529336953121-ad01a50243bd?q=80&w=1400&auto=format&fit=crop';
      case 'gastronomy':
        return 'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?q=80&w=1400&auto=format&fit=crop';
      case 'logistics':
        return 'https://images.unsplash.com/photo-1599050751795-5cda3a0bde01?q=80&w=1400&auto=format&fit=crop';
      case 'lab':
        return 'https://images.unsplash.com/photo-1581090187043-8fba8f06d8f1?q=80&w=1400&auto=format&fit=crop';
      case 'trade':
        return 'https://images.unsplash.com/photo-1581093458791-9d09b1f53749?q=80&w=1400&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?q=80&w=1400&auto=format&fit=crop';
    }
  }

  String _industryKeyForJob(JobModel j) {
    final title = j.title.toLowerCase();
    final industry = (j.industry ?? '').toLowerCase();
    final all = (j.industries + j.tags).map((e) => e.toLowerCase()).join(' ');
    if (RegExp(r'(büro|assistenz|office|verwaltung|sachbearbeiter)', caseSensitive: false).hasMatch('$title $industry $all')) return 'office';
    if (RegExp(r'(gastro|restaurant|service|küche|bar)', caseSensitive: false).hasMatch('$title $industry $all')) return 'gastronomy';
    if (RegExp(r'(lager|logistik|versand|warehouse|fahrer)', caseSensitive: false).hasMatch('$title $industry $all')) return 'logistics';
    if (RegExp(r'(labor|pharma|chemie|biotech|medizin)', caseSensitive: false).hasMatch('$title $industry $all')) return 'lab';
    if (RegExp(r'(handwerk|produktion|fertigung|techniker)', caseSensitive: false).hasMatch('$title $industry $all')) return 'trade';
    return 'default';
  }

  Widget _chips(JobModel j) {
    final chips = <String>[];
    if ((j.experienceLevel ?? '').isNotEmpty) chips.add(j.experienceLevel!);
    if (j.jobType.isNotEmpty) chips.add(j.jobType);
    if ((j.workType ?? '').isNotEmpty) chips.add(j.workType!);
    if ((j.salary ?? '').isNotEmpty) chips.add(j.salary!);
    if (j.location.isNotEmpty) chips.add(j.location.split(',').first);
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) => Chip(
        label: Text(c),
        backgroundColor: AppColors.grey100,
        labelStyle: const TextStyle(fontSize: 12),
      )).toList(),
    );
  }

  String _lead(JobModel j) {
    final city = j.location.split(',').first.trim();
    final strong = j.benefits.firstWhere(
      (b) => RegExp(r'(hybrid|remote|4-?tage|weiterbildung|bonus|modern|zentral|flexibel|work[- ]?life|unbefristet)', caseSensitive: false).hasMatch(b),
      orElse: () => '',
    );
    if (strong.isNotEmpty) return _short('Wir bieten, was andere versprechen: $strong', 90);
    if ((j.workType ?? '').toLowerCase().contains('hybrid')) return 'Hybrid möglich in $city';
    if ((j.workType ?? '').toLowerCase().contains('remote')) return 'Remote möglich';
    return _short('Kurzprofil: moderne Arbeitsweise, faire Bedingungen in $city', 90);
  }

  List<String> _summaryBullets(JobModel j) {
    final items = <String>[];
    final strong = j.benefits.firstWhere(
      (b) => RegExp(r'(hybrid|remote|weiterbildung|bonus|modern|zentral|unbefristet)', caseSensitive: false).hasMatch(b),
      orElse: () => '',
    );
    if (strong.isNotEmpty) items.add(strong);
    if ((j.workType ?? '').isNotEmpty) items.add(j.workType!);
    if ((j.salary ?? '').isNotEmpty) items.add(j.salary!);
    if (j.responsibilities.isNotEmpty) items.add(j.responsibilities.first);
    final seen = <String>{};
    return items.where((s) => seen.add(s.toLowerCase())).map((s) => _short(s, 70)).take(3).toList();
  }

  List<String> _bulletsFrom(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    final raw = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[•\-–\*]\s*'), '').trim())
        .where((l) => l.length > 2)
        .toList();
    // dedupe
    final seen = <String>{};
    return raw.where((l) => seen.add(l.toLowerCase())).take(8).toList();
  }

  Widget _buildSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bullets = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          ...bullets.take(10).map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(b)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // Static version without "Mehr anzeigen"
  Widget _buildSectionStatic(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bullets = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          ...bullets.take(10).map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(b)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// Removed _ExpandableBullets - using static sections only