import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'order', 'weather', 'promo', 'community'
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!_auth.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }
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

  int get _unreadCount =>
      _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'all') return _notifications;
    return _notifications.where((item) {
      final linkType = (item['link_type']?.toString() ?? '').toLowerCase();
      final title = (item['title']?.toString() ?? '').toLowerCase();
      final body = (item['body']?.toString() ?? '').toLowerCase();

      switch (_selectedFilter) {
        case 'order':
          return linkType == 'order' ||
              title.contains('order') ||
              body.contains('order') ||
              title.contains('pre-order');
        case 'weather':
          return linkType == 'weather' ||
              title.contains('weather') ||
              title.contains('rain') ||
              title.contains('storm') ||
              body.contains('weather');
        case 'promo':
          return linkType == 'voucher' ||
              linkType == 'promo' ||
              title.contains('voucher') ||
              title.contains('discount') ||
              title.contains('sale');
        case 'community':
          return linkType == 'post' ||
              linkType == 'comment' ||
              linkType == 'chat' ||
              linkType == 'conversation';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _markAllAsRead() async {
    if (!_auth.isLoggedIn || _unreadCount == 0) return;
    HapticFeedback.mediumImpact();
    try {
      await NotificationService().markAllAsRead(_auth.userId);
      await _fetchNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('All notifications marked as read'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item, int index) async {
    final id = item['notification_id']?.toString() ?? '';
    final linkType = (item['link_type']?.toString() ?? '').toLowerCase();
    final linkId = item['link_id']?.toString() ?? '';
    final isRead = item['is_read'] as bool? ?? false;

    HapticFeedback.lightImpact();

    // Optimistically mark as read in UI
    if (!isRead && id.isNotEmpty) {
      setState(() {
        item['is_read'] = true;
      });
      NotificationService().markAsRead(id);
    }

    // Deep-Link Navigation
    try {
      if (linkType.isNotEmpty) {
        await NotificationService().navigateFromLink(
          linkType: linkType,
          linkId: linkId,
        );
        return;
      }

      // Contextual fallbacks if linkType was empty
      final title = (item['title']?.toString() ?? '').toLowerCase();
      if (title.contains('weather') || title.contains('storm') || title.contains('rain')) {
        context.push('/farmer/weather');
      } else if (title.contains('order')) {
        context.push('/consumer/orders');
      } else if (title.contains('voucher') || title.contains('discount')) {
        context.push('/consumer/vouchers');
      }
    } catch (e) {
      debugPrint('Navigation error on notification tap: $e');
    }
  }

  Future<void> _deleteNotification(String id, int index) async {
    final removedItem = _notifications[index];
    HapticFeedback.selectionClick();

    setState(() {
      _notifications.removeAt(index);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification removed'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF34D399),
          onPressed: () {
            setState(() {
              _notifications.insert(index, removedItem);
            });
          },
        ),
      ),
    );

    try {
      await NotificationService().deleteNotification(id);
    } catch (_) {}
  }

  Future<void> _clearAllNotifications() async {
    if (!_auth.isLoggedIn || _notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text(
              'Clear All Notifications?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
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

  IconData _getNotificationIcon(String type, String title) {
    final lower = '$type $title'.toLowerCase();
    if (lower.contains('order') || lower.contains('ship') || lower.contains('delivery')) {
      return Icons.local_shipping_rounded;
    }
    if (lower.contains('weather') || lower.contains('storm') || lower.contains('rain') || lower.contains('heat')) {
      return Icons.cloud_sync_rounded;
    }
    if (lower.contains('voucher') || lower.contains('discount') || lower.contains('promo')) {
      return Icons.confirmation_number_rounded;
    }
    if (lower.contains('call')) {
      return Icons.phone_in_talk_rounded;
    }
    if (lower.contains('harvest') || lower.contains('crop') || lower.contains('product')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('post') || lower.contains('comment') || lower.contains('community')) {
      return Icons.forum_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _getIconColor(String type, String title) {
    final lower = '$type $title'.toLowerCase();
    if (lower.contains('order') || lower.contains('ship')) return const Color(0xFF0284C7);
    if (lower.contains('weather') || lower.contains('storm')) return const Color(0xFFD97706);
    if (lower.contains('voucher') || lower.contains('discount')) return const Color(0xFFE11D48);
    if (lower.contains('call') || lower.contains('harvest')) return const Color(0xFF059669);
    if (lower.contains('post') || lower.contains('community')) return const Color(0xFF7C3AED);
    return const Color(0xFF059669);
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    final now = DateTime.now();
    for (final item in items) {
      try {
        final createdAt = DateTime.parse(item['created_at']?.toString() ?? '');
        final diffDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(createdAt.year, createdAt.month, createdAt.day))
            .inDays;

        if (diffDays == 0) {
          groups['Today']!.add(item);
        } else if (diffDays == 1) {
          groups['Yesterday']!.add(item);
        } else {
          groups['Earlier']!.add(item);
        }
      } catch (_) {
        groups['Earlier']!.add(item);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;
    final grouped = _groupNotifications(filtered);
    final unread = _unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(unread),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Pills
            if (_notifications.isNotEmpty) _buildFilterCarousel(),

            // Notification List or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF059669),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      color: const Color(0xFF059669),
                      backgroundColor: Colors.white,
                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              children: [
                                if (grouped['Today']!.isNotEmpty) ...[
                                  _buildSectionHeader('TODAY'),
                                  ...grouped['Today']!.asMap().entries.map(
                                    (e) => _buildNotificationCard(e.value, e.key),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (grouped['Yesterday']!.isNotEmpty) ...[
                                  _buildSectionHeader('YESTERDAY'),
                                  ...grouped['Yesterday']!.asMap().entries.map(
                                    (e) => _buildNotificationCard(e.value, e.key),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (grouped['Earlier']!.isNotEmpty) ...[
                                  _buildSectionHeader('EARLIER'),
                                  ...grouped['Earlier']!.asMap().entries.map(
                                    (e) => _buildNotificationCard(e.value, e.key),
                                  ),
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP APP BAR
  // ===========================================================================
  PreferredSizeWidget _buildAppBar(int unread) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF0F172A),
          size: 18,
        ),
        onPressed: () => context.pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unread New',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_notifications.isNotEmpty) ...[
          if (unread > 0)
            IconButton(
              icon: const Icon(
                Icons.done_all_rounded,
                color: Color(0xFF059669),
                size: 20,
              ),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'Clear all',
            onPressed: _clearAllNotifications,
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 2. CATEGORY FILTER CHIP CAROUSEL
  // ===========================================================================
  Widget _buildFilterCarousel() {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.grid_view_rounded},
      {'key': 'order', 'label': 'Orders', 'icon': Icons.local_shipping_rounded},
      {'key': 'weather', 'label': 'Weather', 'icon': Icons.cloud_sync_rounded},
      {'key': 'promo', 'label': 'Promos', 'icon': Icons.confirmation_number_rounded},
      {'key': 'community', 'label': 'Community', 'icon': Icons.forum_rounded},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, idx) {
          final f = filters[idx];
          final key = f['key'] as String;
          final label = f['label'] as String;
          final icon = f['icon'] as IconData;
          final isSelected = _selectedFilter == key;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = key);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF059669).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. RICH CLICKABLE NOTIFICATION CARD
  // ===========================================================================
  Widget _buildNotificationCard(Map<String, dynamic> item, int index) {
    final id = item['notification_id']?.toString() ?? '$index';
    final title = item['title']?.toString() ?? 'Notification';
    final body = item['body']?.toString() ?? '';
    final linkType = (item['link_type']?.toString() ?? '').toLowerCase();
    final createdAt = item['created_at']?.toString() ?? '';
    final isRead = item['is_read'] as bool? ?? false;
    final timeStr = _formatTime(createdAt);

    final iconData = _getNotificationIcon(linkType, title);
    final iconColor = _getIconColor(linkType, title);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _deleteNotification(id, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? const Color(0xFFE2E8F0)
                : const Color(0xFF10B981).withValues(alpha: 0.35),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: isRead ? 0.02 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(item, index),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Themed Category Icon Badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),

                  // Notification Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF475569),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'View',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Color(0xFF059669),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. ENGAGING EMPTY STATE WITH KIKO MASCOT & ACTION BUTTONS
  // ===========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mascot Illustration
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFECFDF5),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/kiko_cloudy.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.notifications_off_rounded,
                    size: 60,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              'You\'re All Caught Up, Partner!',
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'No new alerts or orders needing your attention.\nExplore fresh harvests or check today\'s farm weather!',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Clickable Quick Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/consumer/search');
                    },
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: Text(
                      'Marketplace',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/farmer/weather');
                    },
                    icon: const Icon(Icons.cloud_sync_outlined, size: 16, color: Color(0xFF059669)),
                    label: Text(
                      'Farm Weather',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
