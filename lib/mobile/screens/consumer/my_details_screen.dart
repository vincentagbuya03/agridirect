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
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/widgets/phone_verification_dialog.dart';
import '../../widgets/skeleton_loaders.dart';

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
  bool _isImagePickerActive = false;
  String? _farmerImageUrl;
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
            var rawImagePath = (farmer['image_url'] ?? '').toString().trim();
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
            _farmerImageUrl = await SupabaseDatabase.getSafeUrl(
              rawImagePath,
              defaultBucket: 'uploads',
            );
            await _precacheProfileImage(_farmerImageUrl);

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
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
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
            if (isFarmer) {
              if (_farmerId != null && _farmerId!.isNotEmpty) {
                final result = await SupabaseConfig.client
                    .from('farmers')
                    .update({'image_url': dbPath})
                    .eq('farmer_id', _farmerId!)
                    .select('farmer_id');
                
                updateSuccessful = result.isNotEmpty;
                debugPrint('✅ Database update attempted via farmer_id: $_farmerId. Rows affected: ${result.length}');
              } else {
                final result = await SupabaseConfig.client
                    .from('farmers')
                    .update({'image_url': dbPath})
                    .eq('user_id', userId)
                    .select('farmer_id');
                
                updateSuccessful = result.isNotEmpty;
                debugPrint('✅ Database update attempted via user_id: $userId. Rows affected: ${result.length}');
              }
            } else {
              final result = await SupabaseConfig.client
                  .from('users')
                  .update({'avatar_url': dbPath})
                  .eq('user_id', userId)
                  .select('user_id');
              updateSuccessful = result.isNotEmpty;
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
        var query = SupabaseConfig.client.from('farmers').update({
          'farm_name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
          'residential_address': _addressController.text.trim(),
          'farm_latitude': _parseCoordinate(_latitudeController.text),
          'farm_longitude': _parseCoordinate(_longitudeController.text),
          'image_url': _imageUrlController.text.trim(),
          'free_delivery_min_amount': double.tryParse(_freeDeliveryMinAmountController.text) ?? 0.0,
        });

        if (_farmerId != null && _farmerId!.isNotEmpty) {
          await query.eq('farmer_id', _farmerId!);
        } else {
          await query.eq('user_id', userId);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          isFarmer ? 'Farm Details' : 'Personal Details',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textHeadline,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textHeadline, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ProfileSkeleton(enabled: true),
                    const SizedBox(height: 28),
                    MetricsGridSkeleton(itemCount: 2, enabled: true),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _infoKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image & Header Section
                    _buildModernProfileHeader(isFarmer),
                    const SizedBox(height: 32),
                    const SizedBox(height: 28),
                    // Form fields
                    Text(
                      isFarmer ? 'Farm Information' : 'Personal Information',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name/Farm Name field
                    _buildTextField(
                      controller: _nameController,
                      label: isFarmer ? 'Farm Name' : 'Full Name',
                      icon: Icons.business,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),

                    // Email field (read-only)
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Phone field (Verified SMS OTP for both Farmer & Customer)
                    _buildPhoneField(),
                    const SizedBox(height: 16),

                    if (!isFarmer) ...[
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.description,
                        enabled: _isEditing,
                        maxLines: 3,
                        isRequired: false,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Location section
                    if (isFarmer) ...[
                      Text(
                        'Location Details',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.textHeadline.withValues(alpha: 0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.pin_drop_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Farm Location',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSubtle,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _locationController.text.trim().isNotEmpty
                                        ? _locationController.text.trim()
                                        : 'No location detected yet',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textHeadline,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _addressController,
                        label: 'Residential Address',
                        icon: Icons.home,
                        enabled: _isEditing,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _freeDeliveryMinAmountController,
                        label: 'Minimum Order for Free Delivery (₱)',
                        icon: Icons.local_shipping,
                        enabled: _isEditing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        isRequired: false,
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
                      const SizedBox(height: 16),

                      Text(
                        _hasPinnedCoordinates()
                            ? 'Pinned coordinates ready'
                            : 'No pinned farm location yet',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _hasPinnedCoordinates()
                              ? AppColors.success
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isEditing ? _openFarmPinPicker : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: _isEditing ? AppColors.primary : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          icon: const Icon(Icons.place_rounded),
                          label: Text(
                            _hasPinnedCoordinates()
                                ? 'Update Farm Pin on Map'
                                : 'Pin Farm on Map',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      // Location section removed for customers
                      const SizedBox(height: 32),
                    ],

                    // Action buttons
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernProfileHeader(bool isFarmer) {
    final imageUrl = isFarmer ? _farmerImageUrl : _customerImageUrl;
    final icon = isFarmer ? Icons.agriculture : Icons.person;
    final roleText = isFarmer ? 'Verified Farm Profile' : 'Buyer Profile';
    final name = isFarmer ? _nameController.text : _nameController.text;
    final color = isFarmer ? AppColors.primary : Colors.blue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: (_isUploadingImage || _isImagePickerActive)
                    ? null
                    : () {
                        if (!_isEditing) setState(() => _isEditing = true);
                        _uploadFarmerImage();
                      },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade50,
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 3),
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: Colors.grey[100]),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.grey[100],
                              child: Icon(icon, size: 40, color: Colors.grey.shade400),
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: Icon(icon, size: 40, color: Colors.grey.shade400),
                          ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: -4,
                child: GestureDetector(
                  onTap: (_isUploadingImage || _isImagePickerActive) ? null : _uploadFarmerImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isUploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : 'My Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textHeadline,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isFarmer ? Icons.verified_rounded : Icons.shopping_bag_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  roleText,
                  style: GoogleFonts.inter(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
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
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: enabled ? AppColors.textHeadline : Colors.grey.shade600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: enabled ? AppColors.primary : Colors.grey.shade400, size: 22),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) {
          if (!enabled) return null;

          if (validator != null) {
            return validator(value);
          }

          if (isRequired && (value?.trim().isEmpty ?? true)) {
            return 'This field cannot be empty';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhoneField() {
    final authUser = SupabaseConfig.client.auth.currentUser;
    var phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      phone = (authUser?.phone ?? authUser?.userMetadata?['phone'] ?? '').toString().trim();
    }
    final hasPhone = phone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_iphone_rounded,
              color: Color(0xFF059669),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Number',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasPhone
                      ? () {
                          final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
                          if (digits.length >= 10) {
                            final last10 = digits.substring(digits.length - 10);
                            return '+63 ${last10.substring(0, 3)} ${last10.substring(3, 6)} ${last10.substring(6)}';
                          }
                          return phone;
                        }()
                      : 'No phone linked',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: hasPhone
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await PhoneVerificationDialog.show(
                context,
                initialPhone: _phoneController.text,
                onVerified: (verifiedPhone) {
                  setState(() {
                    _phoneController.text = verifiedPhone;
                  });
                },
              );
              if (success && mounted) {
                _loadDetails();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFECFDF5),
              foregroundColor: const Color(0xFF059669),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFA7F3D0)),
              ),
            ),
            child: Text(
              hasPhone ? 'Update' : 'Verify',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_isEditing) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          label: Text(
            'Edit Details',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _loadDetails();
              setState(() => _isEditing = false);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.textSubtle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveDetails,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppShimmerLoader(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  double? _parseCoordinate(String value) {
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
                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.agridirect.app',
                                retinaMode: RetinaMode.isHighDensity(context),
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
