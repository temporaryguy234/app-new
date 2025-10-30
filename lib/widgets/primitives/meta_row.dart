import 'package:flutter/material.dart';
import '../../config/colors.dart';

class MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const MetaRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.ink500), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
