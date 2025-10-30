import 'package:flutter/material.dart';
import '../../config/colors.dart';

class FilterChipPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const FilterChipPill({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: StadiumBorder(side: BorderSide(color: AppColors.ink200)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.ink500),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink700)),
            ],
          ),
        ),
      ),
    );
  }
}
