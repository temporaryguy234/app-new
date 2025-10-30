import 'package:flutter/material.dart';
import '../../config/colors.dart';

class AppSearchBarPill extends StatelessWidget {
  final String placeholder;
  final VoidCallback onTap;
  const AppSearchBarPill({super.key, required this.placeholder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: AppColors.ink200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: const [
            Icon(Icons.search, color: AppColors.ink400),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search Job, Company & Role',
                style: TextStyle(color: AppColors.ink500, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.mic_none, color: AppColors.ink400),
          ],
        ),
      ),
    );
  }
}
