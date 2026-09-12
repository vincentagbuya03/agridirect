import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/localization/farmer_locale_service.dart';
import '../../../shared/widgets/farmer/farmer_language_toggle.dart';
import '../../../shared/widgets/phone_verification_dialog.dart';

/// Displays and allows editing of user/farmer details.
class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key});

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  late final AuthService _auth;
  final _infoKey = GlobalKey<FormState>();

  // Shared fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  // Farmer-only fields
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _freeDeliveryMinAmountController;

  // Customer-only fields
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  // Image field (both use it)
  late TextEditingController _imageUrlController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isUploadingCover = false;
  bool _isImagePickerActive = false;
  String? _farmerImageUrl;
  String? _farmerCoverUrl;
  String? _customerImageUrl;
  String? _farmerId;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    final authUser = SupabaseConfig.client.auth.currentUser;
    final initialPhone = (authUser?.phone ?? authUser?.userMetadata?['phone'] ?? '').toString().trim();

    _nameController = TextEditingController();
    _emailController = TextEditingController(text: authUser?.email ?? _auth.userEmail);
    _locationController = TextEditingController();
    _addressController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _freeDeliveryMinAmountController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController(text: initialPhone);
    _imageUrlController = TextEditingController();
    _loadDetails();
  }

  Future<void> _precacheProfileImage(String? imageUrl) async {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty || !mounted) return;

    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (e) {
      debugPrint('Error caching profile image: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _freeDeliveryMinAmountController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      setState(() => _isLoading = true);

      final authUser = SupabaseConfig.client.auth.currentUser;
      _emailController.text = authUser?.email ?? _auth.userEmail;

      final userId = (authUser?.id ?? _auth.userId).trim();

      if (userId.isEmpty) {
        debugPrint('⚠️ Cannot load details: userId is empty');
        return;
      }

      if (_auth.isViewingAsFarmer) {
        // Load farmer details
        final farmers = await SupabaseConfig.client
            .from('farmers')
            .select()
            .eq('user_id', userId)
            .limit(1);

        if (farmers.isNotEmpty) {
          final farmer = farmers[0] as Map<String, dynamic>?;
          if (farmer != null) {
            final rawLatitude = farmer['farm_latitude'];
            final rawLongitude = farmer['farm_longitude'];
            final latitudeText = (rawLatitude ?? '').toString();
            final longitudeText = (rawLongitude ?? '').toString();
            var storedLocation = (farmer['location'] ?? '').toString().trim();
            var rawImagePath = (farmer['logo_url'] ?? '').toString().trim();
            final updates = <String, dynamic>{};

            if (storedLocation.isEmpty) {
              final latitude = _parseCoordinate(latitudeText);
              final longitude = _parseCoordinate(longitudeText);

              if (latitude != null && longitude != null) {
                final resolved =
                    await ReverseGeocodingService.resolveFromCoordinates(
                      latitude: latitude,
                      longitude: longitude,
                    );
                storedLocation = resolved.fullAddress.trim();
              }

              if (storedLocation.isEmpty) {
                storedLocation = (farmer['residential_address'] ?? '')
                    .toString()
                    .trim();
              }

              if (storedLocation.isNotEmpty) {
                updates['location'] = storedLocation;
              }
            }

            _nameController.text = farmer['farm_name'] ?? '';
            _locationController.text = storedLocation;
            _addressController.text = farmer['residential_address'] ?? '';
            _latitudeController.text = latitudeText;
            _longitudeController.text = longitudeText;
            _imageUrlController.text = rawImagePath;
            _freeDeliveryMinAmountController.text = (farmer['free_delivery_min_amount'] ?? '0').toString();
            _farmerId = farmer['farmer_id']?.toString(); // 🟢 NEW: Save farmer_id
            
            // 1. Farm Logo is strictly loaded from logo_url (NEVER personal user avatar or face_photo_path)
            final rawLogoPath = (farmer['logo_url'] as String?)?.trim().isNotEmpty == true
                ? (farmer['logo_url'] as String).trim()
                : '';

            if (rawLogoPath.isNotEmpty &&
                !rawLogoPath.contains('face_photo') &&
                !rawLogoPath.contains('valid_id')) {
              _farmerImageUrl = await SupabaseDatabase.getSafeUrl(
                rawLogoPath,
                defaultBucket: 'uploads',
              );
              await _precacheProfileImage(_farmerImageUrl);
            } else {
              _farmerImageUrl = null;
            }

            // 2. Farm Cover Banner is loaded ONLY from cover_url (NEVER image_url or face_photo_path)
            final rawCoverPath = (farmer['cover_url'] as String?)?.trim() ?? '';
            if (rawCoverPath.isNotEmpty) {
              _farmerCoverUrl = await SupabaseDatabase.getSafeUrl(
                rawCoverPath,
                defaultBucket: 'uploads',
              );
              await _precacheProfileImage(_farmerCoverUrl);
            } else {
              _farmerCoverUrl = null;
            }

            if (updates.isNotEmpty) {
              await SupabaseConfig.client
                  .from('farmers')
                  .update(updates)
                  .eq('user_id', userId);
            }
          }
        }
      } else {
        // Load customer details (name, bio, image from users table)
        _nameController.text = _auth.userName;

        // Load bio, phone, and image from users table if they exist
        try {
          final users = await SupabaseConfig.client
              .from('users')
              .select()
              .eq('user_id', userId)
              .limit(1);

          if (users.isNotEmpty) {
            final user = users[0] as Map<String, dynamic>?;
            if (user != null) {
              _bioController.text = user['bio'] ?? '';
              final rawImageUrl =
                  (user['image_url'] ?? user['avatar_url'] ?? '').toString();
              _imageUrlController.text = rawImageUrl;
              _customerImageUrl = await SupabaseDatabase.getSafeUrl(
                rawImageUrl,
                defaultBucket: 'uploads',
              );
              await _precacheProfileImage(_customerImageUrl);
            }
          }
        } catch (e) {
          debugPrint('Error loading customer details: $e');
        }
      }

      // Always load verified phone from users table or Supabase auth
      String loadedPhone = (authUser?.phone ?? authUser?.userMetadata?['phone'] ?? '').toString().trim();

      try {
        final users = await SupabaseConfig.client
            .from('users')
            .select('phone')
            .eq('user_id', userId)
            .limit(1);
        if (users.isNotEmpty) {
          final u = users[0] as Map<String, dynamic>?;
          if (u != null) {
            final tablePhone = (u['phone'] ?? '').toString().trim();
            if (tablePhone.isNotEmpty) {
              loadedPhone = tablePhone;
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading phone: $e');
      }

      if (loadedPhone.isNotEmpty) {
        // Sync to users table if missing
        try {
          await SupabaseConfig.client
              .from('users')
              .update({'phone': loadedPhone})
              .eq('user_id', userId);
        } catch (_) {}
      }

      _phoneController.text = loadedPhone;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadFarmerImage() async {
    if (_isImagePickerActive || _isUploadingImage) return;

    final picker = ImagePicker();
    final isFarmer = _auth.isViewingAsFarmer;
    _isImagePickerActive = true;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 98,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      // Upload to Supabase Storage
      final file = File(pickedFile.path);
      final prefixedUserId = isFarmer ? 'farmer' : 'customer';
      final fileName =
          '${prefixedUserId}_${_auth.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = isFarmer
          ? 'farmer-profiles/$fileName'
          : 'customer-profiles/$fileName';

      // Try uploading to the storage bucket
      String publicUrl;
      try {
        final uploadResponse = await SupabaseConfig.client.storage
            .from('uploads')
            .upload(path, file);

        if (uploadResponse.isEmpty) {
          throw Exception('Upload failed');
        }

        // Get public URL
        publicUrl = SupabaseConfig.client.storage
            .from('uploads')
            .getPublicUrl(path);
      } catch (storageError) {
        // If upload fails, show actual error message
        final errorMessage = storageError.toString();
        debugPrint('❌ Image upload error: $errorMessage');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Upload failed: ${errorMessage.length > 100 ? errorMessage.substring(0, 100) : errorMessage}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Update image URL controllers and state
      if (mounted) {
        // We store the RELATIVE PATH (bucket/filename) in the database for consistency
        final dbPath = 'uploads/$path';
        
        setState(() {
          if (isFarmer) {
            _farmerImageUrl = publicUrl;
          } else {
            _customerImageUrl = publicUrl;
          }
          _imageUrlController.text = dbPath;
        });

        // 🟢 NEW: Immediately sync with database so user doesn't lose the update
        bool updateSuccessful = false;
        try {
          final userId = _auth.userId.isNotEmpty ? _auth.userId : SupabaseConfig.client.auth.currentUser?.id;
          debugPrint('🔍 Attempting to update farmer image for user_id: $userId, farmer_id: $_farmerId');
          
          if (userId != null && userId.isNotEmpty) {
            final result = await SupabaseConfig.client
                .from('users')
                .update({'avatar_url': dbPath})
                .eq('user_id', userId)
                .select('user_id');
            
            updateSuccessful = result.isNotEmpty;
            await _auth.updateUserAvatarUrl(publicUrl);
            if (isFarmer) {
              try {
                await SupabaseConfig.client
                    .from('farmers')
                    .update({
                      'logo_url': dbPath,
                    })
                    .eq('user_id', userId);
              } catch (logoColErr) {
                debugPrint('⚠️ Error updating logo_url on farmers: $logoColErr');
              }
            }
          }
        } catch (dbErr) {
          debugPrint('❌ Database sync error: $dbErr');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload worked but sync failed: $dbErr'), backgroundColor: Colors.orange),
            );
          }
          return; // Stop here on error
        }

        if (!mounted) return;
        await _precacheProfileImage(publicUrl);

        if (mounted) {
          if (updateSuccessful) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile image updated successfully!'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );
            // Wait a moment for the user to see the success message, then pop with success signal
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Not saved: Record not found or permission denied (RLS).'),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 4),
              ),
            );
            debugPrint('⚠️ UI Warning: Update reported 0 rows modified. Check Supabase RLS policies.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isImagePickerActive = false;
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _uploadFarmerCover() async {
    if (_isUploadingCover) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2560,
      maxHeight: 1440,
      imageQuality: 98,
    );
    if (image == null) return;

    setState(() => _isUploadingCover = true);
    try {
      final ext = image.name.split('.').last;
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'covers/$fileName';
      final file = File(image.path);

      // Upload file directly to Supabase Storage 'uploads' bucket
      await SupabaseConfig.client.storage.from('uploads').upload(
        path,
        file,
      );

      final publicUrl = SupabaseConfig.client.storage
          .from('uploads')
          .getPublicUrl(path);

      final userId = _auth.userId.isNotEmpty ? _auth.userId : SupabaseConfig.client.auth.currentUser?.id;
      final dbPath = 'uploads/$path';
      if (userId != null && userId.isNotEmpty) {
        try {
          final coverUpdates = {
            'cover_url': dbPath,
          };
          if (_farmerId != null && _farmerId!.isNotEmpty) {
            await SupabaseConfig.client
                .from('farmers')
                .update(coverUpdates)
                .eq('farmer_id', _farmerId!);
          } else {
            await SupabaseConfig.client
                .from('farmers')
                .update(coverUpdates)
                .eq('user_id', userId);
          }
        } catch (colErr) {
          debugPrint('⚠️ Error updating cover_url: $colErr');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kailangang i-run ang migration para sa cover_url: $colErr'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _farmerCoverUrl = publicUrl;
        });
      }
      await _precacheProfileImage(publicUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm cover photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading cover photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload cover photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _saveDetails() async {
    if (!_infoKey.currentState!.validate()) return;

    try {
      final userId = _auth.userId.isEmpty
          ? SupabaseConfig.currentUser?.id
          : _auth.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('User session expired. Please log in again.');
      }

      setState(() => _isSaving = true);

      if (_auth.isViewingAsFarmer) {
        // Update farmer details
        final Map<String, dynamic> farmerUpdates = {
          'farm_name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
          'residential_address': _addressController.text.trim(),
          'farm_latitude': _parseCoordinate(_latitudeController.text),
          'farm_longitude': _parseCoordinate(_longitudeController.text),
          'free_delivery_min_amount': double.tryParse(_freeDeliveryMinAmountController.text) ?? 0.0,
        };
        if (_imageUrlController.text.trim().isNotEmpty) {
          farmerUpdates['logo_url'] = _imageUrlController.text.trim();
        }
        if (_farmerCoverUrl != null && _farmerCoverUrl!.isNotEmpty) {
          farmerUpdates['cover_url'] = _farmerCoverUrl;
        }

        try {
          var query = SupabaseConfig.client.from('farmers').update(farmerUpdates);
          if (_farmerId != null && _farmerId!.isNotEmpty) {
            await query.eq('farmer_id', _farmerId!);
          } else {
            await query.eq('user_id', userId);
          }
        } catch (updateErr) {
          if (updateErr.toString().contains('cover_url')) {
            debugPrint('⚠️ cover_url column might not exist yet during save, retrying without it: $updateErr');
            farmerUpdates.remove('cover_url');
            var retryQuery = SupabaseConfig.client.from('farmers').update(farmerUpdates);
            if (_farmerId != null && _farmerId!.isNotEmpty) {
              await retryQuery.eq('farmer_id', _farmerId!);
            } else {
              await retryQuery.eq('user_id', userId);
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Update customer details in users table
        await SupabaseConfig.client
            .from('users')
            .update({
              'name': _nameController.text.trim(),
              'bio': _bioController.text.trim(),
              'phone': _phoneController.text.trim(),
              'avatar_url': _imageUrlController.text.trim(),
            })
            .eq('user_id', userId);
      }

      // Refresh auth-cached profile fields (e.g., displayed name in profile header).
      await _auth.initialize();
      await _loadDetails();

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details saved successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFarmer = _auth.isViewingAsFarmer;
    final locale = FarmerLocaleService.instance;

    return ListenableBuilder(
      listenable: locale,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              locale.t(isFarmer ? 'farm_details_title' : 'personal_details_title'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => context.pop(),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: FarmerLanguageToggle(compact: true),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomActionBar(locale),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Form(
                    key: _infoKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zone 1: Unified Storefront Showcase Header (Edge-to-Edge Banner & Logo)
                        _buildHeroStoreCard(isFarmer, locale),

                        // Zone 2: Padded Bento Content Area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildFarmCredentialsCard(isFarmer, locale),
                              if (isFarmer) ...[
                                const SizedBox(height: 16),
                                _buildFarmLogisticsCard(locale),
                              ],
                            ],
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

  /// Modern Store Showcase Header featuring an edge-to-edge banner with frosted
  /// glass action pill, floating circular avatar, and credentials badge cluster.
  Widget _buildHeroStoreCard(bool isFarmer, FarmerLocaleService locale) {
    if (!isFarmer) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildAvatarWithCameraBadge(
              imageUrl: _customerImageUrl,
              icon: Icons.person_rounded,
              isUploading: _isUploadingImage,
              onTap: (_isUploadingImage || _isImagePickerActive) ? null : _uploadFarmerImage,
            ),
            const SizedBox(height: 14),
            Text(
              _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Buyer Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 5),
                  Text(
                    locale.t('buyer_profile'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final farmName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'My Farm Store';
    final location = _locationController.text.trim();
    final barangayOnly = location.isNotEmpty
        ? location.split(',').first.trim()
        : '';

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          // 1. Edge-to-Edge Store Banner (Height: 185px)
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isUploadingCover ? null : _uploadFarmerCover,
                child: SizedBox(
                  width: double.infinity,
                  height: 185,
                  child: _farmerCoverUrl != null && _farmerCoverUrl!.isNotEmpty
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: _farmerCoverUrl!,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              placeholder: (_, _) => Container(color: const Color(0xFFF1F5F9)),
                              errorWidget: (_, _, _) => _buildCoverFallback(locale),
                            ),
                            // Ambient gradient scrim for high contrast
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.35),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildCoverFallback(locale),
                ),
              ),

              // Glassmorphic 'Palitan ang Cover' Pill (Top-Right)
              Positioned(
                top: 14,
                right: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _isUploadingCover ? null : _uploadFarmerCover,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isUploadingCover)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _isUploadingCover ? locale.t('uploading_cover') : locale.t('change_cover'),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Overlapping Farm Avatar (Centered, 50px overlap)
              Positioned(
                bottom: -50,
                child: _buildAvatarWithCameraBadge(
                  imageUrl: _farmerImageUrl,
                  icon: Icons.agriculture_rounded,
                  isUploading: _isUploadingImage,
                  onTap: (_isUploadingImage || _isImagePickerActive) ? null : _uploadFarmerImage,
                ),
              ),
            ],
          ),

          const SizedBox(height: 58), // Clear the overlapping avatar

          // Farm Name & Status Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                Text(
                  farmName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),

                // Badges Cluster Row
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Verified Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 5),
                          Text(
                            locale.t('verified_farm_profile'),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF047857),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Store Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            locale.t('active_store_badge'),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF15803D),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location Chip (if available)
                    if (barangayOnly.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              barangayOnly,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  /// Rich biophilic background for empty cover state with organic concentric rings
  Widget _buildCoverFallback(FarmerLocaleService locale) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF044E3A), Color(0xFF065F46), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle decorative circular watermarks
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 2),
              ),
            ),
          ),
          Positioned(
            left: -35,
            bottom: -35,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 2),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                locale.t('tap_to_change_cover'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                locale.t('no_cover_yet'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithCameraBadge({
    required String? imageUrl,
    required IconData icon,
    required bool isUploading,
    required VoidCallback? onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 98,
          height: 98,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    placeholder: (_, _) => Container(color: const Color(0xFFF1F5F9)),
                    errorWidget: (_, _, _) => Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/icon/logo_v3.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/icon/logo_v3.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40F59E0B),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }

  /// Bento Card 1: Core Farm Credentials and Contact
  Widget _buildFarmCredentialsCard(bool isFarmer, FarmerLocaleService locale) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.t(isFarmer ? 'farm_info_title' : 'personal_info_title'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locale.t('store_credentials_subtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _nameController,
            label: locale.t(isFarmer ? 'farm_name_label' : 'full_name_label'),
            icon: isFarmer ? Icons.storefront_rounded : Icons.person_outline_rounded,
            enabled: _isEditing,
          ),
          const SizedBox(height: 14),

          // Security read-only Email field
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alternate_email_rounded, size: 18, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.t('email_label'),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _emailController.text.trim().isNotEmpty
                            ? _emailController.text.trim()
                            : 'No email registered',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        locale.t('protected_field'),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Zero-truncation Phone Field
          _buildPhoneField(locale),

          if (!isFarmer) ...[
            const SizedBox(height: 14),
            _buildTextField(
              controller: _bioController,
              label: 'Bio',
              icon: Icons.description_outlined,
              enabled: _isEditing,
              maxLines: 3,
              isRequired: false,
            ),
          ],
        ],
      ),
    );
  }

  /// Zero-truncation phone credentials card with stacked layout
  Widget _buildPhoneField(FarmerLocaleService locale) {
    final authUser = SupabaseConfig.client.auth.currentUser;
    var phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      phone = (authUser?.phone ?? authUser?.userMetadata?['phone'] ?? '').toString().trim();
    }
    final hasPhone = phone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Label (Full Text) + Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: Color(0xFF059669),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locale.t('phone_label'),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasPhone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhone ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: Text(
                  hasPhone ? locale.t('phone_verified_badge') : locale.t('phone_unverified_badge'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: hasPhone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bottom Row: Full Number + Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasPhone ? phone : locale.t('phone_empty'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: hasPhone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final success = await PhoneVerificationDialog.show(
                    context,
                    initialPhone: phone,
                  );
                  if (success == true && mounted) {
                    _loadDetails();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFECFDF5),
                  foregroundColor: const Color(0xFF047857),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFA7F3D0), width: 1.2),
                  ),
                ),
                child: Text(
                  hasPhone ? locale.t('phone_update_btn') : locale.t('phone_verify_btn'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bento Card 2: Location, GPS Map Pin, and Delivery Logistics
  Widget _buildFarmLogisticsCard(FarmerLocaleService locale) {
    final hasPin = _hasPinnedCoordinates();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded, size: 20, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locale.t('location_logistics_title'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locale.t('logistics_subtitle'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _addressController,
            label: locale.t('residential_address_label'),
            icon: Icons.home_work_outlined,
            enabled: _isEditing,
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          // Interactive Map Pin Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasPin ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPin ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: hasPin ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasPin ? Icons.place_rounded : Icons.location_off_rounded,
                        size: 22,
                        color: hasPin ? const Color(0xFF047857) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locale.t('map_pin_title'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasPin
                                ? (_locationController.text.trim().isNotEmpty
                                    ? _locationController.text.trim()
                                    : locale.t('pinned_ready'))
                                : locale.t('pinned_empty'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: hasPin ? const Color(0xFF047857) : const Color(0xFF64748B),
                              fontWeight: hasPin ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _isEditing ? _openFarmPinPicker : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF047857),
                      backgroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      side: BorderSide(
                        color: _isEditing ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: Text(
                      hasPin ? locale.t('update_pin_btn') : locale.t('pin_on_map_btn'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _freeDeliveryMinAmountController,
            label: locale.t('free_delivery_min_label'),
            icon: Icons.local_shipping_rounded,
            enabled: _isEditing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            isRequired: false,
            helperText: locale.t('free_delivery_hint'),
            validator: (value) {
               final text = value?.trim() ?? '';
               if (text.isEmpty) return null;
               final parsed = double.tryParse(text);
               if (parsed == null || parsed < 0) {
                 return 'Please enter a valid positive number';
               }
               return null;
            },
          ),
        ],
      ),
    );
  }

  /// Docked bottom action bar providing immediate access to Edit, Save, and Cancel
  Widget _buildBottomActionBar(FarmerLocaleService locale) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: !_isEditing
          ? Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33059669),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                label: Text(
                  locale.t('edit_details_btn'),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        _loadDetails();
                        setState(() => _isEditing = false);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        locale.t('cancel_btn'),
                        style: GoogleFonts.plusJakartaSans(
                           fontWeight: FontWeight.w700,
                           fontSize: 14,
                           color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33059669),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              locale.t('save_details_btn'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
            prefixIcon: Icon(icon, size: 20, color: enabled ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            helperText: helperText,
            helperStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
          validator: validator ?? (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'This field cannot be empty';
            }
            return null;
          },
        ),
      ],
    );
  }

  double? _parseCoordinate(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  bool _hasPinnedCoordinates() {
    final lat = _parseCoordinate(_latitudeController.text);
    final lng = _parseCoordinate(_longitudeController.text);
    return lat != null && lng != null;
  }

  LatLng _getInitialPin() {
    final lat = _parseCoordinate(_latitudeController.text);
    final lng = _parseCoordinate(_longitudeController.text);

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    return const LatLng(10.3157, 123.8854);
  }

  Future<void> _openFarmPinPicker() async {
    final mapController = MapController();
    var selectedPin = _getInitialPin();
    var isLocating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> useCurrentLocation() async {
              setModalState(() => isLocating = true);
              try {
                final serviceEnabled =
                    await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  throw Exception('Location services are disabled.');
                }

                var permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }

                if (permission == LocationPermission.denied ||
                    permission == LocationPermission.deniedForever) {
                  throw Exception('Location permission denied.');
                }

                final position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                );

                selectedPin = LatLng(position.latitude, position.longitude);
                mapController.move(selectedPin, 15);
                setModalState(() {});
              } catch (e) {
                if (!mounted) return;
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Unable to get current location: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setModalState(() => isLocating = false);
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 700,
                height: 560,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pin Farm Location',
                              style: AppTextStyles.headline3,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tap anywhere on the map to place your farm pin.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedPin,
                              initialZoom: 17,
                              minZoom: 5,
                              maxZoom: 19,
                              onTap: (_, point) {
                                setModalState(() => selectedPin = point);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.agridirect.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    width: 48,
                                    height: 48,
                                    point: selectedPin,
                                    alignment: Alignment.bottomCenter,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppColors.primary,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isLocating
                                      ? null
                                      : useCurrentLocation,
                                  icon: isLocating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: AppShimmerLoader(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: const Text('Use Current Location'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Selected: ${selectedPin.latitude.toStringAsFixed(6)}, ${selectedPin.longitude.toStringAsFixed(6)}',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final resolved =
                                        await ReverseGeocodingService.resolveFromCoordinates(
                                          latitude: selectedPin.latitude,
                                          longitude: selectedPin.longitude,
                                        );

                                    final fallbackLocation =
                                        '${selectedPin.latitude.toStringAsFixed(5)}, ${selectedPin.longitude.toStringAsFixed(5)}';

                                    setState(() {
                                      _latitudeController.text = selectedPin
                                          .latitude
                                          .toStringAsFixed(6);
                                      _longitudeController.text = selectedPin
                                          .longitude
                                          .toStringAsFixed(6);
                                      _locationController.text =
                                          resolved.hasData
                                          ? resolved.fullAddress
                                          : fallbackLocation;
                                    });
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  },
                                  child: const Text('Use This Pin'),
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
            );
          },
        );
      },
    );
  }
}
