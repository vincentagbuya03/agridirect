import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../styles/app_theme.dart';

class ReportContentDialog extends StatefulWidget {
  final String contentLabel;
  final String contentTitle;
  final Future<void> Function(String reason, String? details) onSubmit;

  const ReportContentDialog({
    super.key,
    required this.contentLabel,
    required this.contentTitle,
    required this.onSubmit,
  });

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  static const List<String> _reasons = <String>[
    'Spam or misleading',
    'Harassment or hate speech',
    'False information',
    'Inappropriate content',
    'Other',
  ];

  final TextEditingController _detailsController = TextEditingController();
  String _selectedReason = _reasons.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        _selectedReason,
        _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with red shield/warning icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2), // soft red
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.report_gmailerrorred_rounded,
                      color: Color(0xFFEF4444), // coral red
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Report ${widget.contentLabel.toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHeadline,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Content context preview card
              Text(
                'Reported Content:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSubtle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.contentTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.textBody,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Dropdown Reason Form Field
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSubtle),
                decoration: InputDecoration(
                  labelText: 'Reason for Report',
                  labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSubtle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: _reasons
                    .map(
                      (reason) => DropdownMenuItem<String>(
                        value: reason,
                        child: Text(
                          reason,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textHeadline),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedReason = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Details field
              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Details (optional)',
                  labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSubtle),
                  hintText: 'Provide additional details to help our moderation team...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: AppColors.textSubtle,
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444), // Premium Red Warning color
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit Report',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
