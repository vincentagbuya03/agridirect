import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../shared/services/auth/auth_service.dart';
import '../../shared/services/commerce/cart_service.dart';
import '../../shared/widgets/brand_logo.dart';
import 'web_hamburger_menu_button.dart';
import '../../shared/utils/apk_downloader.dart';
import '../../shared/services/community/notification_service.dart';
import '../../shared/services/community/message_service.dart';
import '../../shared/router/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebConsumerNavBar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onNavigate;
  final VoidCallback? onCartTap;
  final bool isCartActive;
  final EdgeInsetsGeometry margin;

  const WebConsumerNavBar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onCartTap,
    this.isCartActive = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<WebConsumerNavBar> createState() => _WebConsumerNavBarState();
}

class _WebConsumerNavBarState extends State<WebConsumerNavBar> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  static bool _dismissedMobileBanner = false;

  int _hoveredNav = -1;

  Future<void> _downloadAndroidApk() async {
    await ApkDownloader.download();
  }

  Widget _buildGlobalMobileAppBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF042F2E), Color(0xFF064E3B)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.android_rounded,
              color: Color(0xFF4ADE80),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get the AgriDirect App',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Enjoy faster load times and push notifications.',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _downloadAndroidApk,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Get APK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              setState(() {
                _dismissedMobileBanner = true;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white60,
              size: 14,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 12,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final sw = MediaQuery.of(context).size.width;
        final compact = sw < 900;
        final isMobile = sw < 650;

        final isFarmerMode = AuthService().isViewingAsFarmer;
        final navItems = isFarmerMode
            ? const ['Dashboard', 'Products', 'Orders', 'Community']
            : const ['Home', 'Shop', 'Community'];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile && !_dismissedMobileBanner)
              _buildGlobalMobileAppBanner(),
            Container(
              margin: widget.margin,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 28,
                vertical: compact ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onNavigate(0),
                      child: BrandLogo(
                        size: isMobile
                            ? BrandLogoSize.small
                            : (compact
                                  ? BrandLogoSize.small
                                  : BrandLogoSize.medium),
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    SizedBox(width: compact ? 12 : 48),
                    ...List.generate(navItems.length, (i) {
                      final isActive = i == widget.currentIndex;
                      final isHovered = _hoveredNav == i;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hoveredNav = i),
                          onExit: (_) => setState(() => _hoveredNav = -1),
                          child: GestureDetector(
                            onTap: () => widget.onNavigate(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 10 : 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isActive
                                    ? _primary.withValues(alpha: 0.1)
                                    : isHovered
                                    ? _border.withValues(alpha: 0.55)
                                    : Colors.transparent,
                              ),
                              child: Text(
                                navItems[i],
                                style: GoogleFonts.inter(
                                  fontSize: compact ? 12 : 14,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? _primary
                                      : isHovered
                                      ? _dark
                                      : _muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const Spacer(),

                  // Only show cart if NOT in Farmer Mode AND not on mobile (since it's in the hamburger menu)
                  if (!isFarmerMode && !isMobile) ...[
                    ListenableBuilder(
                      listenable: CartService(),
                      builder: (context, _) {
                        final cartCount = CartService().itemCount;
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onCartTap,
                            child: Container(
                              width: compact ? 36 : 44,
                              height: compact ? 36 : 44,
                              decoration: BoxDecoration(
                                color: widget.isCartActive
                                    ? _primary.withValues(alpha: 0.12)
                                    : _border.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.isCartActive
                                      ? _primary.withValues(alpha: 0.35)
                                      : _border,
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.shopping_cart_outlined,
                                      color: widget.isCartActive
                                          ? _primary
                                          : _dark,
                                      size: compact ? 18 : 20,
                                    ),
                                  ),
                                  if (cartCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: _primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            cartCount > 99
                                                ? '99+'
                                                : '$cartCount',
                                            style: GoogleFonts.inter(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (AuthService().isLoggedIn && !isMobile) ...[
                    WebMessageIcon(compact: compact),
                    const SizedBox(width: 8),
                    WebNotificationBell(compact: compact),
                    const SizedBox(width: 8),
                  ],

                  if (!isMobile) ...[
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => widget.onNavigate(isFarmerMode ? 4 : 3),
                        child: Container(
                          width: compact ? 36 : 44,
                          height: compact ? 36 : 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                            border: Border.all(color: _primary, width: 1.5),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: _primary,
                            size: compact ? 18 : 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isMobile) ...[
                    const SizedBox(width: 8),
                    WebHamburgerMenuButton(
                      currentIndex: widget.currentIndex,
                      onNavigate: widget.onNavigate,
                      onCartTap: widget.onCartTap,
                      isCartActive: widget.isCartActive,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class WebNotificationBell extends StatefulWidget {
  final bool compact;
  const WebNotificationBell({super.key, this.compact = false});

  @override
  State<WebNotificationBell> createState() => _WebNotificationBellState();
}

class _WebNotificationBellState extends State<WebNotificationBell> {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  RealtimeChannel? _realtimeChannel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final count = await NotificationService().getUnreadNotificationCount(
      userId,
    );
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  void _subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeChannel = _supabase
        .channel('nav-bar-notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _loadUnreadCount();
          },
        )
        .subscribe();
  }

  Future<void> _fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    final list = await NotificationService().getNotifications(
      userId,
      limit: 10,
    );
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await NotificationService().markAllAsRead(userId);
    await _loadUnreadCount();
    await _fetchNotifications();
  }

  void _showNotificationDialog() async {
    await _fetchNotifications();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: const EdgeInsets.only(top: 80, right: 32),
              child: Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 360,
                    height: 480,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Notifications',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              if (_unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    await _markAllAsRead();
                                    setStateDialog(() {});
                                  },
                                  child: Text(
                                    'Mark all as read',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF16A34A),
                                  ),
                                )
                              : _notifications.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.notifications_none_rounded,
                                        size: 40,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No notifications yet',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: _notifications.length,
                                  itemBuilder: (context, index) {
                                    final item = _notifications[index];
                                    final isRead =
                                        item['is_read'] as bool? ?? false;
                                    return Container(
                                      color: isRead
                                          ? Colors.transparent
                                          : const Color(0xFFF3FBF5),
                                      child: ListTile(
                                        onTap: () async {
                                          Navigator.of(dialogContext).pop();
                                          await NotificationService()
                                              .markAsRead(
                                                item['notification_id']
                                                    .toString(),
                                              );
                                          final linkType =
                                              item['link_type']?.toString() ??
                                              '';
                                          final linkId =
                                              item['link_id']?.toString() ?? '';
                                          try {
                                            await NotificationService()
                                                .navigateFromLink(
                                                  linkType: linkType,
                                                  linkId: linkId,
                                                );
                                          } catch (_) {}
                                        },
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFFDCFCE7,
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(
                                              item['link_type']?.toString() ??
                                                  '',
                                            ),
                                            color: const Color(0xFF16A34A),
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          item['title']?.toString() ??
                                              'AgriDirect',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['body']?.toString() ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatTime(
                                                item['created_at']
                                                        ?.toString() ??
                                                    '',
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: const Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'conversation':
        return Icons.chat_bubble_outline_rounded;
      case 'call':
        return Icons.call_outlined;
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'weather':
        return Icons.wb_sunny_outlined;
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _showNotificationDialog,
        child: Container(
          width: widget.compact ? 36 : 44,
          height: widget.compact ? 36 : 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF111827),
                  size: 20,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_unreadCount',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebMessageIcon extends StatefulWidget {
  final bool compact;
  const WebMessageIcon({super.key, this.compact = false});

  @override
  State<WebMessageIcon> createState() => _WebMessageIconState();
}

class _WebMessageIconState extends State<WebMessageIcon> {
  final _messageService = MessageService();
  late Stream<List<MessageConversation>> _inboxStream;
  bool? _lastIsFarmerMode;

  @override
  Widget build(BuildContext context) {
    final isFarmerMode = AuthService().isViewingAsFarmer;
    if (_lastIsFarmerMode != isFarmerMode) {
      _lastIsFarmerMode = isFarmerMode;
      _inboxStream = _messageService.watchInbox(asFarmer: isFarmerMode);
    }

    return StreamBuilder<List<MessageConversation>>(
      stream: _inboxStream,
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (final conv in snapshot.data!) {
            unreadCount += conv.unreadCount;
          }
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              context.go(AppRoutes.messages, extra: {'asFarmer': isFarmerMode});
            },
            child: Container(
              width: widget.compact ? 36 : 44,
              height: widget.compact ? 36 : 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF111827),
                      size: 20,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
