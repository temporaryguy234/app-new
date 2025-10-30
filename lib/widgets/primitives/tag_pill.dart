import 'package:flutter/material.dart';
import '../../config/colors.dart';

class TagPill extends StatelessWidget {
  final String text;
  final bool filled;
  const TagPill(this.text, {super.key, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final decoration = filled
        ? BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12))
        : const ShapeDecoration(color: Colors.white, shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)));
    final color = filled ? AppColors.primary : AppColors.ink700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: decoration,
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
