import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/resume_analysis_model.dart';
import '../main/main_screen.dart';
// Entfernt: externe Primitives; UI wird lokal gerendert

class ResumeScoringScreen extends StatelessWidget {
  final ResumeAnalysisModel analysis;
  const ResumeScoringScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final city = analysis.location.split(',').first.trim();
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Analyse'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Gradient header with score ring and quick pills
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueSurface),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                _ScoreRing(score: analysis.score),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis.name?.trim().isNotEmpty == true ? analysis.name! : 'Dein Profil',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Pill(icon: Icons.place_outlined, label: city.isEmpty ? 'Unbekannt' : city),
                          const SizedBox(width: 8),
                          _Pill(icon: Icons.trending_up, label: analysis.experienceText),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (analysis.topSkills.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: analysis.topSkills.take(3).map((s) => _tagPill(s)).toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

            _SectionCard(
            title: 'Zusammenfassung',
            child: Text(
              analysis.summary,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          _SectionGap(),

          if (analysis.skills.isNotEmpty)
            _SectionCard(
              title: 'Top‑Fähigkeiten',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: analysis.skills.map((s) => _tagPill(s)).toList(),
              ),
            ),
          if (analysis.skills.isNotEmpty) _SectionGap(),

          if (analysis.strengths.isNotEmpty)
            _SectionCard(
              title: 'Stärken',
              child: Column(
                children: analysis.strengths.map((t) => _Bullet(text: t)).toList(),
              ),
            ),
          if (analysis.strengths.isNotEmpty) _SectionGap(),

          if (analysis.improvements.isNotEmpty)
            _SectionCard(
              title: 'Verbesserungen',
              child: Column(
                children: analysis.improvements.map((t) => _Bullet(text: t)).toList(),
              ),
            ),
          if (analysis.improvements.isNotEmpty) _SectionGap(),

          _SectionCard(
            title: 'Empfehlungen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bullet(text: 'Filter öffnen und Stadt/Remote‑Modus setzen'),
                _Bullet(text: 'Mit verbessertem CV bewerben (Profil → CV exportieren)'),
                _Bullet(text: 'Jobs speichern, um Vorschläge zu verfeinern'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ActionButtons(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Schließen'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainScreen(initialTabIndex: 0)),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Passende Jobs finden'),
          ),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  const _ScoreRing({required this.score});
  @override
  Widget build(BuildContext context) {
    final v = (score.clamp(0, 100)) / 100.0;
    final color = score >= 80 ? AppColors.success : (score >= 60 ? AppColors.warning : AppColors.error);
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 8,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text('${score.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.ink500),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Einfache Text-Pill im App-Style (weißer Chip mit feinem Rand)
Widget _tagPill(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: const ShapeDecoration(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.ink700,
      ),
    ),
  );
}

// TagPill is used for simple chips; keep _Pill for icon+label cases

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      ),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('•  ', style: TextStyle(color: AppColors.textSecondary)),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))),
      ]),
    );
  }
}
