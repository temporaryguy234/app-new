import 'package:flutter/material.dart';

class ListSkeleton extends StatelessWidget {
  final int items;
  const ListSkeleton({super.key, this.items = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _cardSkeleton(),
    );
  }

  Widget _cardSkeleton() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _box(40, 40, 8),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _box(double.infinity, 12),
              const SizedBox(height: 6),
              _box(120, 10),
            ])),
            _circle(24),
          ]),
          const SizedBox(height: 12),
          _box(120, 10),
          const SizedBox(height: 6),
          _box(160, 10),
          const SizedBox(height: 8),
          Row(children: [
            _box(60, 22, 22), const SizedBox(width: 8),
            _box(70, 22, 22), const SizedBox(width: 8),
            _box(80, 22, 22),
          ]),
        ]),
      ),
    );
  }

  Widget _box(double w, double h, [double r = 6]) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(r)));

  Widget _circle(double s) =>
      Container(width: s, height: s, decoration: const BoxDecoration(color: Color(0xFFE5E7EB), shape: BoxShape.circle));
}


