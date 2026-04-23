import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../styles/app_theme.dart';
import '../services/admin/admin_service.dart';

class CreateArticleDialog extends StatefulWidget {
  final AdminService adminService;
  const CreateArticleDialog({super.key, required this.adminService});

  @override
  State<CreateArticleDialog> createState() => _CreateArticleDialogState();
}

class _CreateArticleDialogState extends State<CreateArticleDialog> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isPublished = true;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _imageUrlController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || 
        _summaryController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title, summary, and body')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await widget.adminService.createArticle(
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        body: _bodyController.text.trim(),
        coverImageUrl: _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        isPublished: _isPublished,
      );
      
      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800, // Increased width for better writing space
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Curate New Publication',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHeadline),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSubtle),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildField('Article Title', _titleController, hint: 'e.g., The Future of Regenerative Farming'),
              const SizedBox(height: 20),
              _buildField('Summary / Excerpt', _summaryController, hint: 'A short hook to grab readers...', maxLines: 2),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildField(
                      'Cover Image URL (Optional)', 
                      _imageUrlController, 
                      hint: 'https://images.unsplash.com/...'
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: (_isLoading || _isUploadingImage) ? null : () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 85,
                          );
                          
                          if (image == null) return;

                          setState(() => _isUploadingImage = true);
                          try {
                            final bytes = await image.readAsBytes();
                            final url = await widget.adminService.uploadArticleCover(
                              bytes, 
                              '${DateTime.now().millisecondsSinceEpoch}_${image.name}'
                            );
                            if (url != null) {
                              setState(() => _imageUrlController.text = url);
                            } else if (widget.adminService.errorMessage != null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(widget.adminService.errorMessage!),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _isUploadingImage = false);
                          }
                        },
                        icon: _isUploadingImage 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.upload_rounded, size: 20),
                        label: Text(_isUploadingImage ? 'Uploading...' : 'Upload'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_imageUrlController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textSubtle.withValues(alpha: 0.2)),
                      image: DecorationImage(
                        image: NetworkImage(_imageUrlController.text),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () => setState(() => _imageUrlController.clear()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _buildField('Article Body', _bodyController, hint: 'Write the full story here...', maxLines: 10),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: _isPublished,
                    onChanged: (val) => setState(() => _isPublished = val ?? true),
                    activeColor: AppColors.primary,
                  ),
                  const Text('Publish immediately', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isPublished ? 'Publish Article' : 'Save as Draft', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textHeadline)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
