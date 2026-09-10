import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/router/app_routes.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/community/notification_service.dart';
import '../../constants/web_design_tokens.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/web_footer.dart';

/// Dedicated, responsive desktop web notification center for AgriDirect
class WebNotificationsScreen extends StatefulWidget {
  const WebNotificationsScreen({super.key});

  @override
  State<WebNotificationsScreen> createState() => _WebNotificationsScreenState();
}

class _WebNotificationsScreenState extends State<WebNotificationsScreen> {
  final _auth = AuthService();
  final _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedCategory = 'all'; // 'all', 'order', 'weather', 'promo', 'community'
  bool _showUnreadOnly = false;
  String? _hoveredNotificationId;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!_auth.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final list = await _notificationService.getNotifications(
        _auth.userId,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading web notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;

  int _countForCategory(String cat) {
    if (cat == 'all') return _notifications.length;
    return _notifications.where((item) => _itemMatchesCategory(item, cat)).length;
  }

  bool _itemMatchesCategory(Map<String, dynamic> item, String cat) {
    final linkType = (item['link_type']?.toString() ?? '').toLowerCase();
    final title = (item['title']?.toString() ?? '').toLowerCase();
    final body = (item['body']?.toString() ?? '').toLowerCase();

    switch (cat) {
      case 'order':
        return linkType == 'order' ||
            linkType == 'preorder' ||
            title.contains('order') ||
            title.contains('pre-order') ||
            body.contains('order') ||
            body.contains('delivery') ||
            body.contains('shipped');
      case 'weather':
        return linkType == 'weather' ||
            title.contains('weather') ||
            title.contains('rain') ||
            title.contains('storm') ||
            title.contains('heat') ||
            body.contains('weather') ||
            body.contains('rain') ||
            body.contains('flood');
      case 'promo':
        return linkType == 'voucher' ||
            linkType == 'promo' ||
            title.contains('voucher') ||
            title.contains('discount') ||
            title.contains('promo') ||
            title.contains('sale') ||
            body.contains('voucher');
      case 'community':
        return linkType == 'post' ||
            linkType == 'comment' ||
            linkType == 'chat' ||
            linkType == 'conversation' ||
            title.contains('community') ||
            title.contains('post') ||
            body.contains('comment');
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    return _notifications.where((item) {
      if (_showUnreadOnly && (item['is_read'] as bool? ?? false)) {
        return false;
      }
      if (_selectedCategory != 'all' &&
          !_itemMatchesCategory(item, _selectedCategory)) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(
      List<Map<String, dynamic>> items) {
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

  Future<void> _markAllAsRead() async {
    if (!_auth.isLoggedIn || _unreadCount == 0) return;

    // Optimistically mark all in state
    setState(() {
      for (final n in _notifications) {
        n['is_read'] = true;
      }
    });

    try {
      await _notificationService.markAllAsRead(_auth.userId);
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
            backgroundColor: WebDesignTokens.primary,
            behavior: SnackBarBehavior.floating,
            width: 380,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    final id = item['notification_id']?.toString() ?? item['id']?.toString() ?? '';
    final linkType = (item['link_type']?.toString() ?? '').toLowerCase();
    final linkId = item['link_id']?.toString() ?? '';
    final isRead = item['is_read'] as bool? ?? false;

    // Optimistically mark read
    if (!isRead && id.isNotEmpty) {
      setState(() {
        item['is_read'] = true;
      });
      _notificationService.markAsRead(id);
    }

    // Deep-Link Navigation
    try {
      if (linkType.isNotEmpty) {
        await _notificationService.navigateFromLink(
          linkType: linkType,
          linkId: linkId,
        );
        return;
      }

      final title = (item['title']?.toString() ?? '').toLowerCase();
      if (title.contains('weather') || title.contains('storm') || title.contains('rain')) {
        context.go('/weather-radar');
      } else if (title.contains('order') || title.contains('pre-order')) {
        context.go(AppRoutes.customerOrders);
      } else if (title.contains('voucher') || title.contains('discount')) {
        context.go(AppRoutes.vouchers);
      }
    } catch (e) {
      debugPrint('Navigation error on notification tap: $e');
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> item, int indexInFiltered) async {
    final id = item['notification_id']?.toString() ?? item['id']?.toString() ?? '';
    final fullIndex = _notifications.indexOf(item);

    setState(() {
      _notifications.remove(item);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        behavior: SnackBarBehavior.floating,
        width: 400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFF34D399),
          onPressed: () {
            setState(() {
              if (fullIndex >= 0 && fullIndex <= _notifications.length) {
                _notifications.insert(fullIndex, item);
              } else {
                _notifications.add(item);
              }
            });
          },
        ),
      ),
    );

    if (id.isNotEmpty) {
      try {
        await _notificationService.deleteNotification(id);
      } catch (e) {
        debugPrint('Error deleting notification: $e');
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    if (!_auth.isLoggedIn || _notifications.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Clear All Notifications?',
              style: GoogleFonts.rubik(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: WebDesignTokens.dark,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
          style: GoogleFonts.nunitoSans(
            fontSize: 14,
            color: WebDesignTokens.slate600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunitoSans(
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.slate600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final backup = List<Map<String, dynamic>>.from(_notifications);
    setState(() {
      _notifications.clear();
    });

    try {
      await _notificationService.deleteAllNotifications(_auth.userId);
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      setState(() {
        _notifications = backup;
      });
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
      if (diff.inDays < 7) return '${diff.inDays}d ago, ${DateFormat('h:mm a').format(dt)}';
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  IconData _getCategoryIcon(String type, String title) {
    final lower = '$type $title'.toLowerCase();
    if (lower.contains('weather') || lower.contains('rain') || lower.contains('storm')) {
      return Icons.cloud_sync_rounded;
    }
    if (lower.contains('order') || lower.contains('ship') || lower.contains('deliver')) {
      return Icons.local_shipping_rounded;
    }
    if (lower.contains('voucher') || lower.contains('discount') || lower.contains('promo')) {
      return Icons.confirmation_number_rounded;
    }
    if (lower.contains('post') || lower.contains('community') || lower.contains('comment')) {
      return Icons.forum_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Color _getCategoryColor(String type, String title) {
    final lower = '$type $title'.toLowerCase();
    if (lower.contains('weather') || lower.contains('rain') || lower.contains('storm')) {
      return const Color(0xFFD97706); // Amber
    }
    if (lower.contains('order') || lower.contains('ship') || lower.contains('deliver')) {
      return const Color(0xFF0284C7); // Sky Blue
    }
    if (lower.contains('voucher') || lower.contains('discount') || lower.contains('promo')) {
      return const Color(0xFFE11D48); // Rose
    }
    if (lower.contains('post') || lower.contains('community') || lower.contains('comment')) {
      return const Color(0xFF7C3AED); // Violet
    }
    return WebDesignTokens.primary;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;
    final grouped = _groupNotifications(filtered);
    final unread = _unreadCount;

    return Scaffold(
      backgroundColor: WebDesignTokens.bg,
      body: Column(
        children: [
          // ─── AgriDirect Web E-Commerce Header ───
          WebEcomHeader(
            currentIndex: -1,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onSearch: (query) {
              if (query.trim().isNotEmpty) {
                context.go('/shop?q=${Uri.encodeComponent(query.trim())}');
              }
            },
          ),

          // ─── Main Notification Body ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Breadcrumb
                            _buildBreadcrumbs(),
                            const SizedBox(height: 16),

                            // Top Title & Actions Banner
                            _buildTitleBar(unread),
                            const SizedBox(height: 20),

                            // Category Filters & Unread Toggle Bar
                            _buildFilterBar(),
                            const SizedBox(height: 24),

                            // Notification Feed or Empty State
                            if (!_auth.isLoggedIn)
                              _buildAuthRequiredPrompt()
                            else if (_isLoading)
                              _buildLoadingState()
                            else if (filtered.isEmpty)
                              _buildEmptyState()
                            else ...[
                              if (grouped['Today']!.isNotEmpty) ...[
                                _buildSectionHeader('TODAY', grouped['Today']!.length),
                                const SizedBox(height: 10),
                                ...grouped['Today']!.asMap().entries.map(
                                  (e) => _buildNotificationCard(e.value, e.key),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (grouped['Yesterday']!.isNotEmpty) ...[
                                _buildSectionHeader('YESTERDAY', grouped['Yesterday']!.length),
                                const SizedBox(height: 10),
                                ...grouped['Yesterday']!.asMap().entries.map(
                                  (e) => _buildNotificationCard(e.value, e.key),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (grouped['Earlier']!.isNotEmpty) ...[
                                _buildSectionHeader('EARLIER', grouped['Earlier']!.length),
                                const SizedBox(height: 10),
                                ...grouped['Earlier']!.asMap().entries.map(
                                  (e) => _buildNotificationCard(e.value, e.key),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Breadcrumbs ───
  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go(AppRoutes.marketplace),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                const Icon(Icons.home_outlined, size: 15, color: WebDesignTokens.slate500),
                const SizedBox(width: 4),
                Text(
                  'Home',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WebDesignTokens.slate500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded, size: 16, color: WebDesignTokens.slate400),
        ),
        Text(
          'Notifications',
          style: GoogleFonts.nunitoSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: WebDesignTokens.primary,
          ),
        ),
      ],
    );
  }

  // ─── Title & Action Control Bar ───
  Widget _buildTitleBar(int unread) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
        boxShadow: WebDesignTokens.cardRest,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WebDesignTokens.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: WebDesignTokens.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.rubik(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.dark,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: WebDesignTokens.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unread New',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay updated on orders, weather alerts, harvest drops, and community activities.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: WebDesignTokens.slate500,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (_notifications.isNotEmpty && unread > 0)
                OutlinedButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: WebDesignTokens.primary),
                  label: Text(
                    'Mark all as read',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WebDesignTokens.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                    backgroundColor: WebDesignTokens.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              if (_notifications.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _clearAllNotifications,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: Text(
                    'Clear all',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: WebDesignTokens.slate600, size: 20),
                onPressed: _fetchNotifications,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Filter Pills Bar ───
  Widget _buildFilterBar() {
    final categories = [
      {'key': 'all', 'label': 'All', 'icon': Icons.grid_view_rounded},
      {'key': 'order', 'label': 'Orders', 'icon': Icons.local_shipping_outlined},
      {'key': 'weather', 'label': 'Weather AI', 'icon': Icons.cloud_outlined},
      {'key': 'promo', 'label': 'Promos & Vouchers', 'icon': Icons.confirmation_number_outlined},
      {'key': 'community', 'label': 'Community', 'icon': Icons.people_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((c) {
                  final isSelected = _selectedCategory == c['key'];
                  final count = _countForCategory(c['key'] as String);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = c['key'] as String;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? WebDesignTokens.primary : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? WebDesignTokens.primary : WebDesignTokens.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              c['icon'] as IconData,
                              size: 16,
                              color: isSelected ? Colors.white : WebDesignTokens.slate600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c['label'] as String,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : WebDesignTokens.slate700,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : WebDesignTokens.slate600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 24,
            width: 1,
            color: WebDesignTokens.border,
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _showUnreadOnly ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: _showUnreadOnly ? WebDesignTokens.primary : WebDesignTokens.slate400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Unread only',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showUnreadOnly ? WebDesignTokens.primaryDark : WebDesignTokens.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ───
  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: WebDesignTokens.slate500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WebDesignTokens.slate600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }

  // ─── Notification Card ───
  Widget _buildNotificationCard(Map<String, dynamic> item, int index) {
    final id = item['notification_id']?.toString() ?? item['id']?.toString() ?? '$index';
    final title = item['title']?.toString() ?? 'Notification';
    final body = item['body']?.toString() ?? '';
    final isRead = item['is_read'] as bool? ?? false;
    final createdAt = item['created_at']?.toString() ?? '';
    final linkType = item['link_type']?.toString() ?? '';

    final isHovered = _hoveredNotificationId == id;
    final iconData = _getCategoryIcon(linkType, title);
    final accentColor = _getCategoryColor(linkType, title);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredNotificationId = id),
      onExit: (_) => setState(() => _hoveredNotificationId = null),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF9FDFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovered
                  ? WebDesignTokens.primary.withValues(alpha: 0.5)
                  : isRead
                      ? WebDesignTokens.border
                      : const Color(0xFFA7F3D0),
              width: !isRead ? 1.5 : 1.0,
            ),
            boxShadow: isHovered ? WebDesignTokens.cardHover : WebDesignTokens.cardRest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Left unread accent line
                if (!isRead)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: WebDesignTokens.primary,
                    ),
                  ),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleNotificationTap(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Leading Avatar
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              iconData,
                              color: accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: GoogleFonts.rubik(
                                          fontSize: 15,
                                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                          color: isRead ? WebDesignTokens.dark : const Color(0xFF064E3B),
                                        ),
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: WebDesignTokens.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _formatTime(createdAt),
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: WebDesignTokens.slate400,
                                      ),
                                    ),
                                  ],
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    body,
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: isRead ? WebDesignTokens.slate600 : WebDesignTokens.slate700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      'View details',
                                      style: GoogleFonts.nunitoSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: WebDesignTokens.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: WebDesignTokens.primary,
                                    ),
                                    const Spacer(),
                                    if (isHovered)
                                      IconButton(
                                        tooltip: 'Delete notification',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onPressed: () => _deleteNotification(item, index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Loading Shimmer / Indicator ───
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: WebDesignTokens.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              color: WebDesignTokens.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ───
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications found',
              style: GoogleFonts.rubik(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _showUnreadOnly
                  ? "You don't have any unread notifications right now."
                  : 'You are all caught up! New updates, weather alerts, and orders will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: WebDesignTokens.slate500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.marketplace),
              icon: const Icon(Icons.shopping_basket_outlined, size: 18),
              label: const Text('Explore Marketplace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebDesignTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sign In Required Prompt ───
  Widget _buildAuthRequiredPrompt() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebDesignTokens.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: WebDesignTokens.slate400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view notifications',
              style: GoogleFonts.rubik(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WebDesignTokens.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please log in with your AgriDirect account to view your activity and notifications.',
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: WebDesignTokens.slate500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebDesignTokens.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Log In to Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
