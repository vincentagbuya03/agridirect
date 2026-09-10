import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../mobile/screens/support/kiko_ai_chat_screen.dart';
import '../../../shared/router/app_routes.dart';

/// Floating Web Chatbot Widget for Kiko AI Carabao.
/// Can be docked at the bottom-right of any web marketplace or storefront page.
class WebKikoChatbotWidget extends StatefulWidget {
  final double bottomOffset;
  final double rightOffset;

  const WebKikoChatbotWidget({
    super.key,
    this.bottomOffset = 24,
    this.rightOffset = 24,
  });

  @override
  State<WebKikoChatbotWidget> createState() => _WebKikoChatbotWidgetState();
}

class _WebKikoChatbotWidgetState extends State<WebKikoChatbotWidget>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final chatWidth = math.min(420.0, screenSize.width - 32);
    final chatHeight = math.min(620.0, screenSize.height - 110);

    return Positioned(
      bottom: widget.bottomOffset,
      right: widget.rightOffset,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              alignment: Alignment.bottomRight,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: _isOpen
              ? _buildExpandedChatWindow(chatWidth, chatHeight)
              : _buildFloatingTrigger(),
        ),
      ),
    );
  }

  /// 1. Floating Collapsed Trigger Button
  Widget _buildFloatingTrigger() {
    return MouseRegion(
      key: const ValueKey('kiko_trigger_button'),
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _isOpen = true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: _isHovered ? 0.45 : 0.28),
                blurRadius: _isHovered ? 20 : 14,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kiko Avatar with green ring
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/kiko_happy.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ask Kiko AI',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '24/7',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Agri-Advisory & Market Bot',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Floating Expanded Chat Window Container
  Widget _buildExpandedChatWindow(double width, double height) {
    return Container(
      key: const ValueKey('kiko_chat_window'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: KikoAiChatScreen(
          embedMode: true,
          onClose: () => setState(() => _isOpen = false),
          onExpand: () {
            setState(() => _isOpen = false);
            context.go(AppRoutes.kikoAiChat);
          },
        ),
      ),
    );
  }
}
