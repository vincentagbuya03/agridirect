import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_router.dart';
import 'promo_action_screen.dart';

void showMoreActionsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _MoreActionsBottomSheet(),
  );
}

class _MoreActionsBottomSheet extends StatelessWidget {
  const _MoreActionsBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'More Services',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildActionRow(
            context,
            title: 'Equipment Rental',
            subtitle: 'Rent tractors, plows, and more',
            icon: Icons.handyman_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PromoActionScreen(
                    title: 'Equipment Rental',
                    icon: Icons.handyman_rounded,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              );
            },
          ),
          _buildActionRow(
            context,
            title: 'Farm Services',
            subtitle: 'Hire experts and laborers',
            icon: Icons.engineering_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PromoActionScreen(
                    title: 'Farm Services',
                    icon: Icons.engineering_rounded,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              );
            },
          ),
          _buildActionRow(
            context,
            title: 'Community Forum',
            subtitle: 'Connect with other farmers',
            icon: Icons.forum_rounded,
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.community);
            },
          ),
          _buildActionRow(
            context,
            title: 'Weather Alerts',
            subtitle: 'Get accurate farm weather updates',
            icon: Icons.cloud_rounded,
            color: const Color(0xFF0EA5E9),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.weatherRadar);
            },
            isLast: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
