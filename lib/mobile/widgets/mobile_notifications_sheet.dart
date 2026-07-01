import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/services/auth/auth_service.dart';
import '../../shared/services/community/notification_service.dart';
import '../../shared/styles/app_theme.dart';

/// Shows a premium, interactive bottom sheet containing the user's notifications.
void showMobileNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const MobileNotificationsSheet(),
  );
}

class MobileNotificationsSheet extends StatefulWidget {
  const MobileNotificationsSheet({super.key});

  @override
  State<MobileNotificationsSheet> createState() => _MobileNotificationsSheetState();
}

class _MobileNotificationsSheetState extends State<MobileNotificationsSheet> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!_auth.isLoggedIn) return;
    setState(() => _isLoading = true);

    try {
      final list = await NotificationService().getNotifications(_auth.userId);
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (!_auth.isLoggedIn) return;
    try {
      await NotificationService().markAllAsRead(_auth.userId);
      await _fetchNotifications();
    } catch (_) {}
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'call':
        return Icons.phone_in_talk_outlined;
      case 'weather':
        return Icons.wb_sunny_outlined;
      case 'product':
        return Icons.grid_view_rounded;
      case 'post':
        return Icons.forum_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textHeadline,
                  ),
                ),
                if (_notifications.any((n) => !(n['is_read'] as bool? ?? false)))
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: Text(
                      'Mark all as read',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_off_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All caught up!',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeadline,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You have no new notifications.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final isRead = item['is_read'] as bool? ?? false;
                          final linkType = item['link_type']?.toString() ?? '';
                          final linkId = item['link_id']?.toString() ?? '';

                          return Container(
                            color: isRead ? Colors.transparent : const Color(0xFFF0FDF4),
                            child: ListTile(
                              onTap: () async {
                                Navigator.of(context).pop();
                                await NotificationService().markAsRead(
                                  item['notification_id'].toString(),
                                );
                                try {
                                  await NotificationService().navigateFromLink(
                                    linkType: linkType,
                                    linkId: linkId,
                                  );
                                } catch (_) {}
                              },
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFDCFCE7),
                                child: Icon(
                                  _getNotificationIcon(linkType),
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['title']?.toString() ?? 'Notification',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                  color: AppColors.textHeadline,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item['body']?.toString() ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                              ),
                              trailing: Text(
                                _formatTime(item['created_at']?.toString() ?? ''),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
