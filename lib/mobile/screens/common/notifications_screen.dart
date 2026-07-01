import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../../shared/styles/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteNotification(String id, int index) async {
    final removedItem = _notifications[index];
    setState(() {
      _notifications.removeAt(index);
    });

    try {
      await NotificationService().deleteNotification(id);
    } catch (e) {
      // Revert if error
      setState(() {
        _notifications.insert(index, removedItem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    if (!_auth.isLoggedIn) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete all notifications? This action cannot be undone.', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete All', style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await NotificationService().deleteAllNotifications(_auth.userId);
      await _fetchNotifications();
    } catch (_) {
      setState(() => _isLoading = false);
    }
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

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Colors.blue;
      case 'call':
        return Colors.green;
      case 'weather':
        return Colors.orange;
      case 'product':
        return Colors.purple;
      case 'post':
        return Colors.teal;
      default:
        return AppColors.primary;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textHeadline,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: 'Clear all',
              onPressed: _clearAllNotifications,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppColors.primary,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _notifications.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final id = item['notification_id'].toString();
                        final isRead = item['is_read'] as bool? ?? false;
                        final linkType = item['link_type']?.toString() ?? '';
                        final linkId = item['link_id']?.toString() ?? '';

                        return Dismissible(
                          key: Key(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) {
                            _deleteNotification(id, index);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isRead ? AppColors.surface : const Color(0xFFF4FBF7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRead
                                    ? AppColors.textHeadline.withValues(alpha: 0.05)
                                    : AppColors.primary.withValues(alpha: 0.15),
                                width: isRead ? 1 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () async {
                                await NotificationService().markAsRead(id);
                                try {
                                  await NotificationService().navigateFromLink(
                                    linkType: linkType,
                                    linkId: linkId,
                                  );
                                } catch (_) {}
                                _fetchNotifications();
                              },
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getIconColor(linkType).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getNotificationIcon(linkType),
                                  color: _getIconColor(linkType),
                                  size: 22,
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
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['body']?.toString() ?? '',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSubtle,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatTime(item['created_at']?.toString() ?? ''),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textSubtle.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSubtle, size: 20),
                                onPressed: () => _deleteNotification(id, index),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: AppColors.textSubtle.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeadline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no notifications at the moment.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }
}
