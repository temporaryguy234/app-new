import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../config/colors.dart';
import '../../models/job_model.dart';
import '../../services/resume_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../services/premium_service.dart';
import '../profile/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/resume_analysis_model.dart';
import 'special_job_detail_screen.dart';

class SpecialsScreen extends StatefulWidget {
  const SpecialsScreen({super.key});

  @override
  State<SpecialsScreen> createState() => _SpecialsScreenState();
}

class _SpecialsScreenState extends State<SpecialsScreen> {
  final _resumeService = ResumeService();
  List<JobModel> _jobs = [];
  List<JobModel> _teasers = [];
  List<JobModel> _alsoLike = [];
  bool _loading = true;
  final _premium = PremiumService();
  int _starsUsed = 0;
  final ScrollController _outerScrollController = ScrollController();
  bool _lockOuterWhileTeaserDrags = false;
  bool _hasLoaded = false; // Single-fire flag

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_hasLoaded) return; // Single-fire: nur einmal laden
    _hasLoaded = true;
    setState(() { _loading = true; _jobs = []; });
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) { setState(() => _loading = false); return; }
      
      // Use cached jobs instead of triggering new SerpAPI calls
      final jobs = await _resumeService.loadJobsForUser(user.uid);
      _jobs = jobs;
      _computeTeasersAndAlsoLike(_jobs);
      setState(() { _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }


  void _onStarJob(JobModel job) async {
    final can = await _premium.canUseSpecials();
    if (!can) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Premium erforderlich'),
          content: const Text('Du hast die Specials diese Woche bereits genutzt. Für weitere Bewerbungen brauchst du Premium.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Später')),
            TextButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); }, child: const Text('Premium ansehen')),
          ],
        ),
      );
      return;
    }
    
    await _premium.recordSpecialsUse();
    setState(() => _starsUsed++);

    // Speichere unter "Gespeichert" und öffne Bewerbungsseite
    try {
      // optional: await FirestoreService().saveJob(job);
    } catch (_) {}

    final url = job.applicationUrl;
    if (url != null && url.isNotEmpty) {
      try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viel Erfolg! Job liegt auch unter „Gespeichert“.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Specials',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.grey),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Was sind Specials?'),
                    content: const Text('Specials sind handverlesene Job-Angebote, die perfekt zu deinem Profil passen. Du kannst sie mit Sternen markieren und direkt bewerben.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Verstanden'))],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Sterne ($_starsUsed)',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              controller: _outerScrollController,
              physics: _lockOuterWhileTeaserDrags
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              slivers: [
                if (_jobs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.work_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('Keine Specials verfügbar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            const Text('Lade deinen Lebenslauf hoch, um personalisierte Job-Empfehlungen zu erhalten.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Erneut versuchen')),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Teaser-Bereich mit Peek (groß, rechteckig)
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenH = MediaQuery.of(context).size.height;
                        final teaserH = (screenH * 0.68).clamp(360.0, 720.0);
                        return SizedBox(
                          height: teaserH,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n is ScrollStartNotification) {
                                setState(() => _lockOuterWhileTeaserDrags = true);
                              }
                              if (n is ScrollEndNotification) {
                                setState(() => _lockOuterWhileTeaserDrags = false);
                              }
                              return false; // lassen PageView weiterarbeiten
                            },
                            child: PageView.builder(
                              scrollDirection: Axis.horizontal,
                              controller: PageController(viewportFraction: 0.88),
                              padEnds: true,
                              physics: const PageScrollPhysics(),
                              itemCount: _teasers.isEmpty ? 1 : _teasers.length,
                              itemBuilder: (context, index) {
                                final job = _teasers.isEmpty ? _jobs.first : _teasers[index];
                                return _buildTeaserCard(job);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: const [
                          Text('Könnte auch passen', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  // Grid aus bestehenden Ergebnissen (remix)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _gridJobCard(_alsoLike[i]),
                        childCount: _alsoLike.length,
                      ),
                    ),
                  ),
                ]
              ],
            ),
    );
  }

  // Teaser-Karte oben: unscharfes Branchenbild, Gradient, Titel/City oben, Hook in Mitte, ganze Karte klickbar
  Widget _buildTeaserCard(JobModel job) {
    final city = job.location.split(',').first.trim();
    final hookText = _buildHookSentence(job);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpecialJobDetailScreen(job: job)),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Company logo top-left
              Positioned(
                top: 20,
                left: 20,
                child: _companyLogoChip(job, size: 36),
              ),
              // Background: unified blue gradient (uses app token)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: AppColors.blueSurface,
                  ),
                ),
              ),
              // Removed darkening overlay to match grid card look (pure light blue)
              // Title centered near top + published time under it
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -0.7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _cleanTitle(job),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _publishedAgo(job),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // City chip stays top-right
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(city, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              // Mid chips (eye-catcher keyfacts, non-clickable)
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _factChips(job),
                  ),
                ),
              ),
              // Center hook: white card with lead + bullets (Hinge-like) - moved slightly up to avoid overlap
              Positioned.fill(
              child: Align(
                alignment: const Alignment(0, 0.6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: Container(
                     constraints: const BoxConstraints(),
                       padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hookText,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                            Text(
                              _hookSubtext(job),
                              maxLines: 6,
                              overflow: TextOverflow.fade,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Soft bottom fade (already covered by gradient); keep star button only
              Positioned(
                bottom: 28,
                right: 20,
                child: GestureDetector(
                  onTap: () => _onStarJob(job),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Listen für Teaser und AlsoLike berechnen (ohne neue API)
  void _computeTeasersAndAlsoLike(List<JobModel> jobs) {
    if (jobs.isEmpty) {
      _teasers = [];
      _alsoLike = [];
      return;
    }

    // 1) Deduplicate by company + normalized title (ignore location/url noise)
    final unique = _dedupeByKey(jobs);

    // 2) Sort newest first if postedAt exists, otherwise stable
    unique.sort((a, b) {
      final ad = a.postedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.postedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    // 3) Helper to pick diverse set by company
    List<JobModel> pickDiverse(List<JobModel> list, int count) {
      final seenCompanies = <String>{};
      final picked = <JobModel>[];
      for (final j in list) {
        final c = (j.company ?? '').toLowerCase().trim();
        if (seenCompanies.add(c) || picked.length < 3) {
          picked.add(j);
        }
        if (picked.length >= count) break;
      }
      // Fill if diversity ran out
      if (picked.length < count) {
        for (final j in list) {
          if (picked.length >= count) break;
          if (!picked.any((p) => _sameJob(p, j))) picked.add(j);
        }
      }
      return picked;
    }

    // 4) Keep some for grid: 5–6 teasers max, depending on total
    final teaserCount = unique.length >= 10
        ? 6
        : (unique.length >= 6
            ? 5
            : (unique.length >= 3 ? 3 : unique.length));
    final teasers = pickDiverse(unique, teaserCount);

    // 5) Grid: take the rest; ensure at least 4–8 items
    final rest = unique.where((j) => !teasers.any((t) => _sameJob(t, j))).toList();
    final also = <JobModel>[];
    also.addAll(rest.take(8));

    if (also.length < 8) {
      for (final j in unique) {
        if (also.length >= 8) break;
        if (!also.any((x) => _sameJob(x, j)) && !teasers.any((t) => _sameJob(t, j))) {
          also.add(j);
        }
      }
    }
    if (also.length < 4) {
      for (final t in teasers.skip(1)) {
        if (also.length >= 4) break;
        if (!also.any((x) => _sameJob(x, t))) also.add(t);
      }
    }

    _teasers = teasers;
    _alsoLike = also.take(8).toList();
  }

  Widget _gridJobCard(JobModel job) {
    final teaser = _gridTeaser(job);
    final summary = _gridSummary(job);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpecialJobDetailScreen(job: job)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF4FF), Color(0xFFD3E9FF)],
          ),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _companyLogoChip(job, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cleanTitle(job),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _gridFacts(job).map(_pill).toList(),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location.split(',').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small company avatar/logo helper
  Widget _companyLogoChip(JobModel job, {double size = 24}) {
    final logo = job.companyLogo;
    final company = job.company.trim();
    final initials = company.isNotEmpty
        ? company.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join('')
        : '•';
    final borderRadius = BorderRadius.circular(8);
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsBox(initials, size),
        ),
      );
    }
    return _initialsBox(initials, size);
  }

  Widget _initialsBox(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: (size * 0.45).clamp(10, 16).toDouble(),
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _short(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max - 1)}…';
  }

  String _cleanTitle(JobModel j) {
    var title = (j.title).trim().replaceAll(RegExp(r'\s+'), ' ');
    // Normalize (m/w/d)
    title = title.replaceAll(RegExp(r'\(m\s*/\s*w\s*/\s*d\)', caseSensitive: false), '(m/w/d)');

    final missingRole = title.isEmpty ||
        title.toLowerCase().startsWith('(m/w/d)') ||
        RegExp(r'^\(m/w/d\)\s*(in\s+(teilzeit|vollzeit))?$', caseSensitive: false).hasMatch(title);

    if (missingRole) {
      final role = _inferRoleFrom(j) ?? 'Mitarbeiter';
      final wt = _inferWorkType(j);
      title = '$role (m/w/d)${wt.isNotEmpty ? ' $wt' : ''}';
    } else if (title.endsWith('(m/w/d)')) {
      final wt = _inferWorkType(j);
      if (wt.isNotEmpty && !title.toLowerCase().contains(wt.toLowerCase())) {
        title = '$title $wt';
      }
    }

    // Keep tidy length
    return title.length > 60 ? '${title.substring(0, 57).trimRight()}…' : title;
  }

  String? _inferRoleFrom(JobModel j) {
    final pools = <String>[
      ...j.tags,
      j.jobType,
      ...j.industries,
      ...j.skills,
      (j.description ?? '')
    ].join(' ').toLowerCase();

    // Common role keywords
    final roleRe = RegExp(
      r'(empfangsmitarbeiter|kundenservice|verk(ä|ae)ufer|kassierer|b(ü|u)rokaufmann|sachbearbeiter|lagerhelfer|fahrer|rein(igungskraft|iger)|vertriebsmitarbeiter|assistenz|sekret(ä|ae)r|marketing(?:-)?manager|servicekraft|koch|kellner|it[- ]support|datenerfasser|call[- ]center)',
      caseSensitive: false,
    );
    final m = roleRe.firstMatch(pools);
    if (m != null) {
      var role = m.group(0)!;
      // Capitalize first letter
      role = role[0].toUpperCase() + role.substring(1);
      return role;
    }
    return null;
  }

  String _inferWorkType(JobModel j) {
    final wt = ('${j.workType ?? ''} ${j.jobType}'.toLowerCase());
    if (wt.contains('teilzeit')) return 'in Teilzeit';
    if (wt.contains('vollzeit')) return 'in Vollzeit';
    if (wt.contains('werkstudent')) return 'als Werkstudent';
    if (wt.contains('praktikum')) return 'im Praktikum';
    return '';
  }

  String _firstSentence(String text, {int maxChars = 110}) {
    // Remove leading conjunctions, trim to sentence boundary
    final cleaned = text.replaceAll(RegExp(r'^\s*(und|oder|aber|sowie|sodass|dass)\s+', caseSensitive: false), '')
                        .replaceAll(RegExp(r'^\s*[–\-•]\s*'), '').trim();
    // Match up to sentence end (. ! ?)
    final m = RegExp(r'^.{1,' + maxChars.toString() + r'}(?:(?<=\.)|(?<=[!?]))').firstMatch(cleaned);
    return (m?.group(0) ?? cleaned).trim();
  }

  String _publishedAgo(JobModel j) {
    final dt = j.postedAt;
    if (dt == null) return 'Kürzlich veröffentlicht';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Veröffentlicht vor $m Min.';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Veröffentlicht vor $h Std.';
    }
    if (diff.inDays < 14) {
      final d = diff.inDays;
      return 'Veröffentlicht vor $d Tagen';
    }
    final weeks = (diff.inDays / 7).floor();
    return 'Veröffentlicht vor $weeks Wochen';
  }

  String _buildHookSentence(JobModel j) {
    // Lead line is always the same to create a strong CTA
    return 'Bewirb dich hier, wenn du...';
  }

  String _hookSubtext(JobModel j) {
    // Compose a comprehensive, compelling feature list ending with "suchst."
    final parts = <String>{};
    final lowerDesc = (j.description ?? '').toLowerCase();
    final lowerBenefits = j.benefits.map((b) => b.toLowerCase()).join(' ');

    // Core, always compelling hook items
    parts.add('einen modernen Arbeitsplatz');
    parts.add('klare Aufgaben');
    parts.add('echte Entwicklung');

    // High-impact benefits that hook people
    if (RegExp(r'wertsch|feedback|ehrlich|kultur|team|mentor', caseSensitive: false).hasMatch(lowerDesc)) {
      parts.add('ehrliches Feedback');
    }
    if (RegExp(r'bonus|prämie|beteiligung|aktien|provision', caseSensitive: false).hasMatch(lowerBenefits)) {
      parts.add('attraktive Boni');
    }
    if (RegExp(r'weiterbildung|fortbildung|schulung|zertifikat|training', caseSensitive: false).hasMatch(lowerBenefits)) {
      parts.add('Weiterbildungsmöglichkeiten');
    }
    if (RegExp(r'flexibel|work[- ]?life|familienfreundlich|sabbatical', caseSensitive: false).hasMatch(lowerBenefits)) {
      parts.add('Work-Life-Balance');
    }
    if (RegExp(r'unbefristet|festanstellung|sicherheit', caseSensitive: false).hasMatch(lowerBenefits)) {
      parts.add('einen unbefristeten Vertrag');
    }

    // Work model perks
    final wt = (j.workType ?? '').toLowerCase();
    if (wt.contains('remote')) parts.add('100% Remote-Flexibilität');
    if (wt.contains('hybrid')) parts.add('Hybrid-Freiheit');
    if (wt.contains('4-') || wt.contains('vier')) parts.add('4-Tage-Woche');

    // Salary/compensation
    if ((j.salary ?? '').isNotEmpty) {
      if (RegExp(r'überdurchschnittlich|top|attraktiv|konkurrenzfähig', caseSensitive: false).hasMatch(j.salary!.toLowerCase())) {
        parts.add('überdurchschnittliche Bezahlung');
      } else {
        parts.add('faire Bezahlung');
      }
    }

    // Company perks
    if (RegExp(r'startup|scale|wachstum|innovativ|modern|digital', caseSensitive: false).hasMatch(lowerDesc)) {
      parts.add('ein innovatives Umfeld');
    }
    if (RegExp(r'team|kollegen|zusammenarbeit|gemeinsam', caseSensitive: false).hasMatch(lowerDesc)) {
      parts.add('ein starkes Team');
    }

    // Take 6-8 strongest, most compelling items to fill the box
    final list = parts.take(8).toList();
    if (list.isEmpty) list.addAll(['einen modernen Arbeitsplatz', 'klare Aufgaben', 'echte Entwicklung', 'faire Bezahlung', 'ein starkes Team', 'Weiterbildungsmöglichkeiten']);

    final sentence = _joinWithCommaUnd(list);
    return '$sentence suchst.';
  }

  String _joinWithCommaUnd(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} und ${items[1]}';
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head und ${items.last}';
  }

  Widget _factChips(JobModel j) {
    final facts = <(String, Color, Color)>[];

    // Core job info chips
    if ((j.workType ?? '').isNotEmpty) facts.add((j.workType!, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8))); // richer blue
    if ((j.jobType).isNotEmpty) facts.add((j.jobType, const Color(0xFFE9D5FF), const Color(0xFF6D28D9))); // richer purple
    if ((j.salary ?? '').isNotEmpty) facts.add((j.salary!, const Color(0xFFD1FAE5), const Color(0xFF047857))); // richer green
    if ((j.experienceLevel ?? '').isNotEmpty) facts.add((j.experienceLevel!, const Color(0xFFFDE68A), const Color(0xFF92400E))); // amber
    
    // Location chip
    final city = j.location.split(',').first.trim();
    if (city.isNotEmpty) facts.add((city, const Color(0xFFFDE68A), const Color(0xFF92400E))); // amber

    // Remote/Home office chips
    double remoteValue = 0;
    if (j.remotePercentage is num) {
      remoteValue = (j.remotePercentage as num).toDouble();
    } else if (j.remotePercentage is String) {
      final str = j.remotePercentage as String;
      remoteValue = double.tryParse(RegExp(r'\d+').firstMatch(str)?.group(0) ?? '0') ?? 0;
    }
    final remotePositive = remoteValue > 0;
    final hasRemote = (j.workType ?? '').toLowerCase().contains('remote') || remotePositive;
    if (hasRemote) {
      facts.add(('Remote', const Color(0xFFBAE6FD), const Color(0xFF0EA5E9))); // cyan
    }
    if ((j.workType ?? '').toLowerCase().contains('home')) {
      facts.add(('Homeoffice', const Color(0xFFC7D2FE), const Color(0xFF4338CA))); // indigo
    }

    // Contract type from description
    final desc = (j.description ?? '').toLowerCase();
    if (RegExp('unbefristet').hasMatch(desc)) {
      facts.add(('Unbefristet', const Color(0xFFE0E7FF), const Color(0xFF4338CA)));
    } else if (RegExp('befristet').hasMatch(desc)) {
      facts.add(('Befristet', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)));
    }

    // Company size chip
    if (j.companySize.isNotEmpty) {
      facts.add((j.companySize, const Color(0xFFE9D5FF), const Color(0xFF6D28D9)));
    }

    // Industry chip
    if (j.industry.isNotEmpty) {
      facts.add((j.industry, const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)));
    }

    // Skills chips (up to 2)
    for (final skill in j.skills.take(2)) {
      if (facts.length >= 8) break;
      if (skill.trim().isNotEmpty) {
        facts.add((skill, const Color(0xFFBBF7D0), const Color(0xFF166534))); // green
      }
    }

    // Industries chips (up to 2)
    for (final industry in j.industries.take(2)) {
      if (facts.length >= 8) break;
      if (industry.trim().isNotEmpty) {
        facts.add((industry, const Color(0xFFFDE68A), const Color(0xFFD97706))); // yellow
      }
    }

    // Tags chips (up to 3)
    for (final tag in j.tags.take(3)) {
      if (facts.length >= 8) break;
      if (tag.trim().isNotEmpty) {
        facts.add((tag, const Color(0xFFFDE68A), const Color(0xFF9A3412))); // orange
      }
    }

    // Benefits chips (up to 2)
    for (final benefit in j.benefits.take(2)) {
      if (facts.length >= 8) break;
      if (benefit.trim().isNotEmpty) {
        facts.add((benefit, const Color(0xFFBAE6FD), const Color(0xFF0369A1))); // sky blue
      }
    }

    // Fallback chips if still not enough
    if (facts.length < 6) {
      facts.add(('Schneller Start', const Color(0xFFF0FDF4), const Color(0xFF166534)));
    }
    if (facts.length < 7) {
      facts.add(('Teamorientiert', const Color(0xFFFEF3C7), const Color(0xFFD97706)));
    }
    if (facts.length < 8) {
      facts.add(('Moderne Tools', const Color(0xFFF0F9FF), const Color(0xFF0369A1)));
    }

    final shown = facts.take(8).toList();

    // Assign bright, varied colors without repetition per card
    final labels = <String>[];
    for (final f in shown) {
      if (!labels.contains(f.$1)) labels.add(f.$1);
    }
    final palette = <(Color, Color)>[
      (const Color(0xFFFECACA), const Color(0xFFB91C1C)), // bright red
      (const Color(0xFF93C5FD), const Color(0xFF1D4ED8)), // bright blue
      (const Color(0xFFA7F3D0), const Color(0xFF065F46)), // bright green
      (const Color(0xFFFCD34D), const Color(0xFF92400E)), // bright amber
      (const Color(0xFFD8B4FE), const Color(0xFF6D28D9)), // bright purple
      (const Color(0xFFA7F3F0), const Color(0xFF0F766E)), // bright teal
      (const Color(0xFFFBCFE8), const Color(0xFFBE185D)), // bright pink
      (const Color(0xFFC7D2FE), const Color(0xFF4338CA)), // bright indigo
      (const Color(0xFFD9F99D), const Color(0xFF3F6212)), // bright lime
      (const Color(0xFFBAE6FD), const Color(0xFF0284C7)), // bright cyan
    ];

    final chipWidgets = <Widget>[];
    for (int i = 0; i < labels.length; i++) {
      final (bg, fg) = palette[i % palette.length];
      chipWidgets.add(_factChip(labels[i], bg, fg));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chipWidgets,
    );
  }

  Widget _factChip(String text, Color bg, Color fg) {
    // Align to app-wide pill style for consistency
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.ink700, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  List<String> _pickHooks(JobModel j) {
    final items = <String>[];
    final city = j.location.split(',').first.trim();
    
    // 1) Differenzierende Benefits/Arbeitsweise
    final strong = j.benefits.firstWhere(
      (b) => RegExp(r'(hybrid|remote|4-?tage|weiterbildung|mentor|bonus|modern|zentral|flexibel|work[- ]?life|familienfreundlich|sabbatical|unbefristet|home ?office)', caseSensitive: false).hasMatch(b),
      orElse: () => '',
    );
    if (strong.isNotEmpty) items.add('Wir bieten, was andere versprechen: $strong');

    // 2) Team-/Kultur-/Besonderheiten aus Beschreibung/Tags
    final desc = (j.description ?? '').toString();
    final cultureMatch = RegExp(r"[^.!?\n]{0,120}(team|kultur|mentoring|coaching|wertsch|impact|eigenverantwortung)[^.!?\n]{0,120}", caseSensitive: false).firstMatch(desc);
    final culture = (cultureMatch?.group(0) ?? '').replaceAll('\n', ' ').trim();
    if (culture.isNotEmpty) items.add('Hier ist etwas anders: $culture');

    // 3) Arbeitsmodell prägnant
    if ((j.workType ?? '').toLowerCase().contains('hybrid')) items.add('Hybrid möglich in $city');
    if ((j.workType ?? '').toLowerCase().contains('remote')) items.add('Remote möglich');

    // 4) Fallbacks
    if (items.isEmpty) {
      items.addAll(['Modernes Office in $city', 'Faires Gehalt & ehrliches Feedback']);
    }

    // dedupe + shorten + drop lead duplicate
    final lead = _buildHookSentence(j);
    final seen = <String>{};
    final cleaned = items
        .where((s) => s.trim().isNotEmpty && s != lead)
        .map((s) => _short(s, 60))
        .where((s) => seen.add(s))
        .take(3)
        .toList();

    return cleaned;
  }

  String _buildUsp(JobModel j) {
    final city = j.location.split(',').first.trim();
    final strong = j.benefits.firstWhere(
      (b) => RegExp(r'(hybrid|remote|4-?tage|weiterbildung|bonus|modern|zentral|flexibel|work[- ]?life)', caseSensitive: false).hasMatch(b),
      orElse: () => '',
    );
    if (strong.isNotEmpty) {
      return '$strong · $city';
    }
    return 'Gute Bedingungen · $city';
  }

  List<String> _buildPills(JobModel j) {
    final pills = <String>[];
    if ((j.experienceLevel ?? '').isNotEmpty) pills.add(j.experienceLevel!);
    if (j.jobType.isNotEmpty) pills.add(j.jobType);
    if ((j.salary ?? '').isNotEmpty) pills.add(j.salary!);
    if (pills.isEmpty) pills.addAll(['Schneller Start', 'Teamorientiert']);
    return pills.take(3).toList();
  }


  String _hintLocation(String original, String override) {
    if (override == 'Remote') return 'Remote';
    final parts = original.split(',').map((e) => e.trim()).toList();
    return override.isNotEmpty ? '$override, Germany' : (parts.isNotEmpty ? '${parts.first}, Germany' : 'Germany');
  }

  bool _sameJob(JobModel a, JobModel b) {
    final ka = '${(a.company ?? '').toLowerCase()}|${_normalizeTitle(a.title)}';
    final kb = '${(b.company ?? '').toLowerCase()}|${_normalizeTitle(b.title)}';
    return ka == kb;
  }

  List<JobModel> _dedupeByKey(Iterable<JobModel> items) {
    final seen = <String>{};
    return items.where((j) {
      final key = '${(j.company ?? '').toLowerCase()}|${_normalizeTitle(j.title)}';
      return seen.add(key);
    }).toList();
  }

  String _normalizeTitle(String t) {
    return t.toLowerCase()
        .replaceAll(RegExp(r'\(m\s*/\s*w\s*/\s*d\)|\(w\s*/\s*m\s*/\s*d\)|\(d\s*/\s*m\s*/\s*w\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bin\s+(teilzeit|vollzeit|werkstudent|praktikum)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // --- Helpers: Background image + industry palettes ---
  String? _backgroundImageUrlForJob(JobModel j) {
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
    final combined = '$title $industry $all';
    
    // More comprehensive industry detection
    if (RegExp(r'(büro|assistenz|office|verwaltung|sachbearbeiter|admin|sekretär|marketing|verkauf|sales|vertrieb)', caseSensitive: false).hasMatch(combined)) return 'office';
    if (RegExp(r'(gastro|restaurant|service|küche|bar|kellner|koch|hotel)', caseSensitive: false).hasMatch(combined)) return 'gastronomy';
    if (RegExp(r'(lager|logistik|versand|warehouse|fahrer|transport|spedition)', caseSensitive: false).hasMatch(combined)) return 'logistics';
    if (RegExp(r'(labor|pharma|chemie|biotech|medizin|forschung|wissenschaft)', caseSensitive: false).hasMatch(combined)) return 'lab';
    if (RegExp(r'(handwerk|produktion|fertigung|techniker|mechaniker|elektriker)', caseSensitive: false).hasMatch(combined)) return 'trade';
    if (RegExp(r'(it|software|programmier|entwickler|computer|digital|web|app)', caseSensitive: false).hasMatch(combined)) return 'office';
    
    return 'default';
  }

  (Color, Color) _paletteForIndustry(String key) {
    switch (key) {
      case 'office':
        return (const Color(0xFFF4F6FA), const Color(0xFFEFF3F9)); // grau-blau
      case 'gastronomy':
        return (const Color(0xFFFAF6F1), const Color(0xFFF5EDE1)); // warmes beige
      case 'logistics':
        return (const Color(0xFFF1F6F3), const Color(0xFFE9F2ED)); // grau-grün
      case 'lab':
        return (const Color(0xFFF3F7FA), const Color(0xFFEAF2F9)); // kühles hellblau
      case 'trade':
        return (const Color(0xFFF6F6F4), const Color(0xFFEFEFEA)); // neutrales warmgrau
      default:
        return (AppColors.grey50, AppColors.grey100);
    }
  }

  String _gridTeaser(JobModel j) {
    // choose a concise, convincing keyword (no "Einstieg möglich")
    final benefit = j.benefits.firstWhere(
      (b) => RegExp(r'(hybrid|remote|weiterbildung|bonus|mentoring|modern|zentral|unbefristet|work[- ]?life|dienstwagen|beteiligung|frühe verantwortung|entwicklung)', caseSensitive: false).hasMatch(b),
      orElse: () => '',
    );
    if (benefit.isNotEmpty) return benefit;
    if ((j.salary ?? '').isNotEmpty) return j.salary!;
    if ((j.workType ?? '').isNotEmpty) return j.workType!;
    if (j.responsibilities.isNotEmpty) return j.responsibilities.first;
    final city = j.location.split(',').first.trim();
    return 'Modernes Office in $city';
  }

  String _gridSummary(JobModel j) {
    final parts = <String>[];
    if ((j.workType ?? '').isNotEmpty) parts.add(j.workType!);
    final benefit = j.benefits.firstWhere((b) => b.length > 8 && b.length < 50, orElse: () => '');
    if (benefit.isNotEmpty) {
      parts.add(benefit);
    } else if (j.responsibilities.isNotEmpty) {
      final resp = j.responsibilities.first;
      if (resp.length > 8 && resp.length < 50) parts.add(resp);
    }
    if ((j.experienceLevel ?? '').isNotEmpty) parts.add(j.experienceLevel!);
    final s = parts.take(2).join(' • ').trim();
    return s;
  }

  List<String> _gridFacts(JobModel j) {
    final facts = <String>[];
    if ((j.salary ?? '').isNotEmpty) facts.add(j.salary!);
    final wt = (j.workType ?? '').isNotEmpty ? j.workType! : (j.jobType.isNotEmpty ? j.jobType : '');
    if (wt.isNotEmpty) facts.add(wt);
    if ((j.experienceLevel ?? '').isNotEmpty) facts.add(j.experienceLevel!);

    final wtLower = ('${j.workType ?? ''} ${j.jobType}').toLowerCase();
    final hasRemote = wtLower.contains('remote') ||
        (j.remotePercentage is num && (j.remotePercentage as num) > 0);
    if (hasRemote) facts.add('Remote möglich');

    if (facts.length < 3 && j.benefits.isNotEmpty) facts.add(j.benefits.first);
    // Enrich with tags or skills if still too few
    if (facts.length < 2 && j.tags.isNotEmpty) {
      for (final t in j.tags) {
        if (facts.length >= 3) break; final s = _shortLabel(t);
        if (!facts.contains(s) && s.isNotEmpty) facts.add(s);
      }
    }
    if (facts.length < 2 && j.skills.isNotEmpty) {
      for (final t in j.skills) {
        if (facts.length >= 3) break; final s = _shortLabel(t);
        if (!facts.contains(s) && s.isNotEmpty) facts.add(s);
      }
    }
    if (facts.isEmpty) facts.addAll(['Schneller Start','Gute Bedingungen']);
    return facts.take(3).map(_shortLabel).toList();
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
      ),
      child: Text(_shortLabel(text), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _shortLabel(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= 20) return t;
    return t.substring(0, 19).trimRight() + '…';
  }
}


