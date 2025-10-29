import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../config/colors.dart';
import '../services/premium_service.dart';

class JobCard extends StatefulWidget {
  final JobModel job;
  final Future<void> Function(JobModel job)? onApply; // optional full override for apply
  final bool isPremium;

  const JobCard({
    super.key,
    required this.job,
    this.onApply,
    this.isPremium = false,
  });

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragUpdate: (_) {},
          child: Container(
            height: constraints.maxHeight, // fill screen height
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient header block with logo, title, company, meta rows and pills
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.blueSurface,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _companyAvatar(job),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    if ((job.company ?? '').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          job.company!,
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if ((job.location ?? '').isNotEmpty)
                            _meta(Icons.place_outlined, job.location!.split(',').first.trim()),
                          if ((job.salary ?? '').isNotEmpty)
                            _meta(Icons.payments_outlined, job.salary!),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if ((job.workType ?? '').toLowerCase().contains('remote') ||
                                  ((job.remotePercentage ?? '').toString().isNotEmpty))
                                _pill('Remote'),
                              if (job.jobType.isNotEmpty) _pill(job.jobType),
                              if ((job.experienceLevel ?? '').isNotEmpty) _pill(job.experienceLevel!),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Kurzprofil'),
                    const SizedBox(height: 6),
                    Text(
                      _summaryFromJob(job),
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    ...(() {
                      final req = job.requirements.isNotEmpty ? job.requirements : _compactFromParagraphOffset(job.description, 0);
                      if (req.isEmpty) return <Widget>[];
                      return [
                        _sectionTitle('Was du können musst'),
                        const SizedBox(height: 8),
                        ..._bulletList(req),
                        const SizedBox(height: 16),
                      ];
                    })(),

                    ...(() {
                      List<String> resp = job.responsibilities.isNotEmpty ? job.responsibilities : _compactFromParagraphOffset(job.description, 1);
                      // De-duplicate if fallback produced similar lists
                      if (job.responsibilities.isEmpty && job.requirements.isEmpty) {
                        final reqSet = _compactFromParagraphOffset(job.description, 0).toSet();
                        resp = resp.where((e) => !reqSet.contains(e)).toList();
                      }
                      if (resp.isEmpty) return <Widget>[];
                      return [
                        _sectionTitle('Was dich erwartet'),
                        const SizedBox(height: 8),
                        ..._bulletList(resp),
                        const SizedBox(height: 16),
                      ];
                    })(),

                    ...(() {
                      final bens = job.benefits.isNotEmpty ? job.benefits : _compactFromParagraph(job.companyDescription);
                      if (bens.isEmpty) return <Widget>[];
                      return [
                        _sectionTitle('Benefits'),
                        const SizedBox(height: 8),
                        ..._bulletList(bens),
                        const SizedBox(height: 16),
                      ];
                    })(),

                    if (job.companySize.isNotEmpty || job.companyDescription.isNotEmpty || job.industry.isNotEmpty) ...[
                      _sectionTitle('Über das Unternehmen'),
                      const SizedBox(height: 8),
                      if (job.industry.isNotEmpty) _bullet('Branche: ${job.industry}'),
                      if (job.companySize.isNotEmpty) _bullet('Größe: ${job.companySize}'),
                      if (job.companyDescription.isNotEmpty) _bullet(job.companyDescription),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      child: ElevatedButton(
                        onPressed: () async {
                          if (widget.onApply != null) {
                            await widget.onApply!(widget.job);
                            return;
                          }
                          final service = PremiumService();
                          final canAuto = await service.canAutoApply();
                          if (canAuto) {
                            await service.recordAutoApply();
                            await _openApplicationLink(context);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto‑Bewerbung gestartet')),
                              );
                            }
                          } else {
                            await _openApplicationLink(context);
                            if (mounted && !widget.isPremium) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Limit erreicht: Auto‑Bewerben ist mit Premium unbegrenzt.')),
                              );
                            }
                          }
                        },
                        child: const Text('Bewerben'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                      child: TextButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/profile');
                        },
                        label: const Text('Mit verbessertem CV bewerben'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  Future<void> _openApplicationLink(BuildContext context) async {
    final job = widget.job;
    if (job.applicationUrl != null && job.applicationUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(job.applicationUrl!);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) _showErrorSnackBar(context, 'Link konnte nicht geöffnet werden');
      } catch (e) {
        _showErrorSnackBar(context, 'Fehler beim Öffnen des Links');
      }
    } else {
      _showErrorSnackBar(context, 'Kein Bewerbungslink verfügbar');
    }
  }

  Widget _companyAvatar(JobModel job) {
    final companyName = job.company ?? 'Company';
    final initials = companyName.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() : '').take(2).join('');

    final derived = _deriveLogoFromUrl(job.applicationUrl);
    if ((job.companyLogo != null && job.companyLogo!.isNotEmpty) || (derived != null)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          (job.companyLogo != null && job.companyLogo!.isNotEmpty) ? job.companyLogo! : derived!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsBox(initials),
        ),
      );
    }

    return _initialsBox(initials);
  }

  Widget _initialsBox(String initials) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  String? _deriveLogoFromUrl(String? applyUrl) {
    if (applyUrl == null || applyUrl.isEmpty) return null;
    Uri? uri;
    try { uri = Uri.parse(applyUrl); } catch (_) { return null; }
    if (uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    const blocked = [
      'linkedin.com', 'indeed.', 'stepstone.', 'arbeitsagentur.', 'monster.', 'glassdoor.', 'xing.',
      'job', 'karriere', 'stellen', 'jooble', 'workwise.', 'ziprecruiter.'
    ];
    if (blocked.any((b) => host.contains(b))) return null;
    return 'https://logo.clearbit.com/$host';
  }

  Widget _keyFactsLine(JobModel job) {
    final facts = <String>[];
    
    if ((job.salary ?? '').isNotEmpty) facts.add(job.salary!);
    if ((job.workType ?? '').isNotEmpty) facts.add(job.workType!);
    if ((job.location ?? '').isNotEmpty) {
      final city = job.location!.split(',').first.trim();
      facts.add(city);
    }
    
    return Text(
      facts.join(' • '),
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink700),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.ink500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _summaryFromJob(JobModel j) {
    // 1) Context line: role + company + city + work type
    final role = j.title.replaceAll(RegExp(r'\(m\/w\/d\)', caseSensitive: false), '').trim();
    final company = (j.company ?? '').trim();
    final city = (j.location ?? '').split(',').first.trim();
    final workType = ((j.workType ?? '').isNotEmpty ? j.workType : (j.jobType.isNotEmpty ? j.jobType : null));

    final StringBuffer buffer = StringBuffer('Als ');
    buffer.write(role.isNotEmpty ? role : 'Mitarbeiter');
    if (company.isNotEmpty) buffer.write(' bei $company');
    if (city.isNotEmpty) buffer.write(' in $city');
    if ((workType ?? '').isNotEmpty) buffer.write(' (${workType!})');
    buffer.write('. ');

    // 2) Duties/benefits line: pick 2–3 concise points
    List<String> lines = [];
    if (j.responsibilities.isNotEmpty) lines = j.responsibilities;
    if (lines.isEmpty && j.requirements.isNotEmpty) lines = j.requirements;
    if (lines.isEmpty && j.benefits.isNotEmpty) lines = j.benefits;

    final cleaned = lines
        .map((s) => s.replaceAll(RegExp(r'^[•\\-–]\\s*'), '').trim())
        .where((s) => s.length >= 8)
        .map((s) => s.length > 90 ? '${s.substring(0, 90).trimRight()}…' : s)
        .take(3)
        .toList();

    if (cleaned.isNotEmpty) {
      buffer.write('${cleaned.join(', ')}.');
      return buffer.toString().trim();
    }

    // 3) Fallback to a compact sentence from description
    final desc = (j.description ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (desc.isNotEmpty) {
      final m = RegExp(r'[^.!?]{8,150}[.!?]').firstMatch(desc);
      buffer.write(m != null ? m.group(0) : (desc.length > 150 ? '${desc.substring(0, 150)}…' : desc));
    }
    return buffer.toString().trim();
  }

  List<String> _compactFromParagraph(String? paragraph, {int maxBullets = 4}) {
    final p = (paragraph ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    if (p.isEmpty) return [];
    final bullets = p.split(RegExp(r'(?:•|-|–|\u2022)\s+')).where((s) => s.trim().isNotEmpty).toList();
    if (bullets.length >= 3) return bullets.map((s) => s.trim()).take(maxBullets).toList();
    final sent = RegExp(r'[^.!?]{8,140}[.!?]').allMatches(p).map((m) => m.group(0)!.trim()).toList();
    return sent.take(maxBullets).toList();
  }

  List<String> _compactFromParagraphOffset(String? paragraph, int offset, {int maxBullets = 4}) {
    final p = (paragraph ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    if (p.isEmpty) return [];
    final sentences = RegExp(r'[^.!?]{8,140}[.!?]').allMatches(p).map((m) => m.group(0)!.trim()).toList();
    if (sentences.isEmpty) return _compactFromParagraph(paragraph, maxBullets: maxBullets);
    final picked = <String>[];
    for (int i = offset; i < sentences.length && picked.length < maxBullets; i += 2) {
      picked.add(_truncateNicely(sentences[i], 120));
    }
    return picked;
  }

  String _truncateNicely(String text, int max) {
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final idx = cut.lastIndexOf(' ');
    final base = idx > 60 ? cut.substring(0, idx) : cut;
    return base.trimRight() + '…';
  }

  List<Widget> _bulletList(List<String> items, {int max = 4}) {
    return items.take(max).map(_bullet).toList();
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog nicht mehr genutzt (kein Anschreiben erforderlich)

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
