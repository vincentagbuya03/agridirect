import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../styles/app_theme.dart';
import '../data/app_data.dart';
import '../services/core/supabase_data_service.dart';
import '../widgets/image_widgets.dart';
import '../services/auth/auth_service.dart';

class CreatePostDialog extends StatefulWidget {
  const CreatePostDialog({super.key});

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  XFile? _selectedImage;
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showCustomSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _submit() async {
    var title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      _showCustomSnackBar('Please write something first!', isError: true);
      return;
    }

    // Default title if empty
    if (title.isEmpty) {
      title = body.split('\n').first;
      if (title.length > 40) {
        title = '${title.substring(0, 37)}...';
      }
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          imageUrl = await SupabaseDataService().uploadForumImage(bytes: bytes);
        } else {
          imageUrl = await SupabaseDataService().uploadForumImage(localPath: _selectedImage!.path);
        }
      }

      await SupabaseDataService().addForumPost(
        ForumPostItem(
          id: '', 
          userName: 'You', 
          time: 'Just now',
          title: title,
          body: body,
          imageUrl: imageUrl,
          likes: 0,
          comments: 0,
          isLiked: false,
        ),
      );
      
      if (mounted) {
        _showCustomSnackBar('Post published successfully!', isError: false);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('Failed to post: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final displayName = auth.isLoggedIn ? auth.userName : 'Guest';
    final avatarUrl = auth.isLoggedIn ? auth.userAvatarUrl : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 550),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Styled Header (Centered Title, Close X removed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Center(
                  child: Text(
                    'Create post',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info Row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: ClipOval(
                            child: SafeNetworkImage(
                              imageUrl: avatarUrl,
                              defaultBucket: 'uploads',
                              fit: BoxFit.cover,
                              placeholder: Container(color: Colors.grey[200]),
                              errorWidget: const Icon(Icons.person, color: Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.public, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Public Community Hub',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 12, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Title Input (Optional)
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a title (optional)...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Divider(height: 16, thickness: 0.5),

                    // Body Input
                    TextField(
                      controller: _bodyController,
                      maxLines: null,
                      minLines: 4,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's on your mind, ${displayName.split(' ').first}?",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image attachment preview
                    if (_selectedImage != null)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(_selectedImage!.path, width: double.infinity, fit: BoxFit.cover)
                                  : Image.file(File(_selectedImage!.path), width: double.infinity, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),

                    // Facebook-style Toolbar Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add to your post',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF22C55E)),
                            tooltip: 'Photo/video',
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.label_important_rounded, color: Color(0xFF3B82F6)),
                            tooltip: 'Tag Farmer',
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.emoji_emotions_rounded, color: Color(0xFFEAB308)),
                            tooltip: 'Feeling/activity',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cancel & Post Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                foregroundColor: const Color(0xFF64748B),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Post',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
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
    );
  }
}
