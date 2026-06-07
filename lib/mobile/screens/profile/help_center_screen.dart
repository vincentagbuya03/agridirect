import 'package:flutter/material.dart';
import '../../../shared/styles/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HelpCard(
            icon: Icons.lock_reset_rounded,
            title: 'Password & Login',
            body:
                'Open Profile > App Settings > Change Password to update your password while logged in.',
          ),
          _HelpCard(
            icon: Icons.person_outline_rounded,
            title: 'Update Profile Details',
            body:
                'Open My Details from your profile to edit your name, photo, phone number, farm details, and location.',
          ),
          _HelpCard(
            icon: Icons.location_on_outlined,
            title: 'Delivery Addresses',
            body:
                'Use Address Book to add, edit, delete, and choose your default delivery address.',
          ),
          _HelpCard(
            icon: Icons.favorite_outline_rounded,
            title: 'Favorites',
            body:
                'Saved offline products appear in Favorites so you can revisit them quickly later.',
          ),
          _HelpCard(
            icon: Icons.support_agent_rounded,
            title: 'Need more help?',
            body:
                'If something still feels off, use Messages to contact sellers or revisit your profile tools to update account info.',
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline3),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSubtle,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
