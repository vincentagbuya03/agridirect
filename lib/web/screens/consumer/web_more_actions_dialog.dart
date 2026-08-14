import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';

class WebMoreActionsDialog extends StatelessWidget {
  const WebMoreActionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
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
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildActionRow(
              context,
              title: 'Equipment Rental',
              subtitle: 'Rent tractors, plows, and more',
              icon: Icons.handyman_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.of(context).pop();
                // Go to equipment rental web screen
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
                // Go to farm services web screen
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
            const SizedBox(height: 16),
          ],
        ),
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
    return _HoverableActionRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
      isLast: isLast,
    );
  }
}

class _HoverableActionRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;

  const _HoverableActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLast = false,
  });

  @override
  State<_HoverableActionRow> createState() => _HoverableActionRowState();
}

class _HoverableActionRowState extends State<_HoverableActionRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.05) : Colors.transparent,
            border: widget.isLast
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
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right, 
                color: _isHovered ? widget.color : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
