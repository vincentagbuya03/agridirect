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
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  XFile? _selectedMedia;
  bool _isVideo = false;
  final _picker = ImagePicker();

  bool get _selectedMediaIsVideo {
    if (_selectedMedia == null) return false;
    final name = _selectedMedia!.name.toLowerCase();
    final path = _selectedMedia!.path.toLowerCase();
    return _isVideo ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.avi') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm') ||
        name.endsWith('.3gp') ||
        path.contains('.mp4') ||
        path.contains('.mov');
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _selectedMedia = image;
          _isVideo = false;
        });
      }
    } catch (e) {
      _showCustomSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        setState(() {
          _selectedMedia = video;
          _isVideo = true;
        });
      }
    } catch (e) {
      _showCustomSnackBar('Error picking video: $e', isError: true);
    }
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();

    if (body.isEmpty) {
      _showCustomSnackBar('Please write something first!', isError: true);
      return;
    }

    // Auto-generate title from body
    var title = body.split('\n').first;
    if (title.length > 40) {
      title = '${title.substring(0, 37)}...';
    }

    setState(() => _isLoading = true);
    try {
      String? imageUrl;
      String? videoUrl;
      if (_selectedMedia != null) {
        if (_selectedMediaIsVideo) {
          if (kIsWeb) {
            final bytes = await _selectedMedia!.readAsBytes();
            videoUrl = await SupabaseDataService().uploadForumVideo(bytes: bytes);
          } else {
            videoUrl = await SupabaseDataService().uploadForumVideo(localPath: _selectedMedia!.path);
          }
        } else {
          if (kIsWeb) {
            final bytes = await _selectedMedia!.readAsBytes();
            imageUrl = await SupabaseDataService().uploadForumImage(bytes: bytes);
          } else {
            imageUrl = await SupabaseDataService().uploadForumImage(localPath: _selectedMedia!.path);
          }
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
          videoUrl: videoUrl,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Styled Header with Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    const SizedBox(width: 28), // Spacer to balance close button
                    Expanded(
                      child: Text(
                        'Create post',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

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
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
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
                                style: GoogleFonts.plusJakartaSans(
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
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.public, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Public Community Hub',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Body Input
                    TextField(
                      controller: _bodyController,
                      maxLines: null,
                      minLines: 5,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF1E293B),
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's on your mind, ${displayName.split(' ').first}?",
                        hintStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Media attachment preview
                    if (_selectedMedia != null)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _selectedMediaIsVideo
                                  ? Container(
                                      color: const Color(0xFFF8FAFC),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.video_file_rounded,
                                            color: AppColors.primary,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              _selectedMedia!.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1E293B),
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Video selected (Ready to upload)',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : (kIsWeb
                                      ? Image.network(_selectedMedia!.path, width: double.infinity, fit: BoxFit.cover)
                                      : Image.file(File(_selectedMedia!.path), width: double.infinity, fit: BoxFit.cover)),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMedia = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Toolbar Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFFF8FAFC),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Add to your post',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                            tooltip: 'Photo',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE6F4EA),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.video_library_rounded, color: Color(0xFFEF4444)),
                            tooltip: 'Video',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFCE8E6),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                foregroundColor: const Color(0xFF64748B),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Post',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
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
