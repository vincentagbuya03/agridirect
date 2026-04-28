import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: Text('Report ${widget.contentLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contentTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headline3.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons
                  .map(
                    (reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedReason = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Add context to help moderators review this report.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
