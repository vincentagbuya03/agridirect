import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumConfirmDialog extends StatefulWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final String loadingText;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color confirmButtonColor;
  final Future<void> Function()? onConfirm;

  const PremiumConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = 'Cancel',
    this.confirmText = 'Log Out',
    this.loadingText = 'Logging out...',
    this.icon = Icons.logout_rounded,
    this.iconColor = const Color(0xFFEF4444),
    this.iconBgColor = const Color(0xFFFEE2E2),
    this.confirmButtonColor = const Color(0xFFEF4444),
    this.onConfirm,
  });

  @override
  State<PremiumConfirmDialog> createState() => _PremiumConfirmDialogState();
}

class _PremiumConfirmDialogState extends State<PremiumConfirmDialog> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    if (widget.onConfirm != null) {
      setState(() => _isLoading = true);
      try {
        await widget.onConfirm!();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        rethrow;
      }
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Icon Container with Soft Background
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Content
                  Text(
                    widget.content,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Action Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            foregroundColor: const Color(0xFF64748B),
                          ),
                          child: Text(
                            widget.cancelText,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Confirm Button
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleConfirm,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: widget.confirmButtonColor,
                            disabledBackgroundColor: widget.confirmButtonColor
                                .withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        widget.loadingText,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  widget.confirmText,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
