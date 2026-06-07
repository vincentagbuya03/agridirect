import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/social/follow_service.dart';
import '../../../shared/styles/app_theme.dart';

class FarmerFollowersScreen extends StatefulWidget {
  const FarmerFollowersScreen({super.key});

  @override
  State<FarmerFollowersScreen> createState() => _FarmerFollowersScreenState();
}

class _FarmerFollowersScreenState extends State<FarmerFollowersScreen> {
  final FollowService _followService = FollowService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _followers = const [];

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoading = true);

    final followers = await _followService.getFollowersForFarmer();
    if (!mounted) return;

    setState(() {
      _followers = followers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('My Followers', style: AppTextStyles.headline3),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFollowers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_followers.isEmpty)
              _buildEmptyState()
            else
              ..._followers.map(_buildFollowerCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final followerLabel = _followers.length == 1
        ? '1 customer follows you'
        : '${_followers.length} customers follow you';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.secondary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_followers.length}',
                  style: AppTextStyles.headline2.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  followerLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 30,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text('No followers yet', style: AppTextStyles.headline3),
          const SizedBox(height: 8),
          Text(
            'When customers follow your farm, they will appear here and receive updates about your new products and posts.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSubtle,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerCard(Map<String, dynamic> follower) {
    final joinedAt = follower['followedAt'] as DateTime?;
    final joinedLabel = joinedAt == null
        ? 'Recently followed your farm'
        : 'Followed on ${_formatDate(joinedAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildAvatar(
            follower['avatarUrl']?.toString() ?? '',
            follower['name']?.toString() ?? 'Customer',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  follower['name']?.toString().trim().isNotEmpty == true
                      ? follower['name'].toString()
                      : 'Customer',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if ((follower['email']?.toString().trim().isNotEmpty ?? false))
                  Text(
                    follower['email'].toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSubtle,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  joinedLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String rawUrl, String name) {
    final initials = _initialsFor(name);

    return FutureBuilder<String?>(
      future: SupabaseDatabase.getSafeUrl(rawUrl, defaultBucket: 'uploads'),
      builder: (context, snapshot) {
        final safeUrl = snapshot.data ?? '';
        if (safeUrl.isNotEmpty) {
          return ClipOval(
            child: CachedNetworkImage(
              imageUrl: safeUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _buildInitialAvatar(initials),
            ),
          );
        }

        return _buildInitialAvatar(initials);
      },
    );
  }

  Widget _buildInitialAvatar(String initials) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
