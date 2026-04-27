import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _locationController = TextEditingController();
    _addressController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
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
    _bioController.dispose();
    _phoneController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      setState(() => _isLoading = true);

      _emailController.text = _auth.userEmail;

      final userId = _auth.userId.isEmpty ? SupabaseConfig.currentUser?.id : _auth.userId;
      
      if (userId == null || userId.isEmpty) {
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
            _nameController.text = farmer['farm_name'] ?? '';
            _locationController.text = farmer['location'] ?? '';
            _addressController.text = farmer['residential_address'] ?? '';
            _latitudeController.text = (farmer['farm_latitude'] ?? '')
                .toString();
            _longitudeController.text = (farmer['farm_longitude'] ?? '')
                .toString();
            _imageUrlController.text = farmer['image_url'] ?? '';
            _farmerImageUrl = await SupabaseDatabase.getSafeUrl(farmer['image_url'] as String?, defaultBucket: 'uploads');
            await _precacheProfileImage(_farmerImageUrl);
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
              _phoneController.text =
                  (user['phone'] ?? user['phone_number'] ?? '').toString();

              final rawImageUrl = (user['image_url'] ?? user['avatar_url'] ?? '').toString();
              _imageUrlController.text = rawImageUrl;
              _customerImageUrl = await SupabaseDatabase.getSafeUrl(rawImageUrl, defaultBucket: 'uploads');
              await _precacheProfileImage(_customerImageUrl);
            }
          }
        } catch (e) {
          debugPrint('Error loading customer details: $e');
          // Continue with just name loaded
        }
      }
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
            .from('uploads') // Create this bucket in Supabase Storage
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
        setState(() {
          if (isFarmer) {
            _farmerImageUrl = publicUrl;
          } else {
            _customerImageUrl = publicUrl;
          }
          _imageUrlController.text = publicUrl;
        });

        if (!mounted) return;
        await _precacheProfileImage(publicUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
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
      final userId = _auth.userId.isEmpty ? SupabaseConfig.currentUser?.id : _auth.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('User session expired. Please log in again.');
      }

      setState(() => _isSaving = true);

      if (_auth.isViewingAsFarmer) {
        // Update farmer details
        await SupabaseConfig.client
            .from('farmers')
            .update({
              'farm_name': _nameController.text.trim(),
              'location': _locationController.text.trim(),
              'residential_address': _addressController.text.trim(),
              'farm_latitude': _parseCoordinate(_latitudeController.text),
              'farm_longitude': _parseCoordinate(_longitudeController.text),
              'image_url': _imageUrlController.text.trim(),
            })
            .eq('user_id', userId);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          isFarmer ? 'Farm Details' : 'Personal Details',
          style: AppTextStyles.headline3,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    // Profile Image Section (both farmers and customers)
                    _buildProfileImageSection(isFarmer),
                    const SizedBox(height: 28),

                    // Header card with role info
                    _buildHeaderCard(isFarmer),
                    const SizedBox(height: 28),

                    // Form fields
                    Text(
                      isFarmer ? 'Farm Information' : 'Personal Information',
                      style: AppTextStyles.headline3,
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

                    // Phone field
                    if (!isFarmer) ...[
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.description,
                        enabled: _isEditing,
                        maxLines: 3,
                        isRequired: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        isRequired: false,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;

                          final phoneRegex = RegExp(r'^[+0-9()\-\s]{7,20}$');
                          if (!phoneRegex.hasMatch(text)) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Location section
                    if (isFarmer) ...[
                      Text('Location Details', style: AppTextStyles.headline3),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
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
                                    'Farm Location (auto from pin)',
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
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textHeadline,
                                      fontWeight: FontWeight.w600,
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
                          icon: const Icon(Icons.place_rounded),
                          label: Text(
                            _hasPinnedCoordinates()
                                ? 'Update Farm Pin on Map'
                                : 'Pin Farm on Map',
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

  Widget _buildProfileImageSection(bool isFarmer) {
    final imageUrl = isFarmer ? _farmerImageUrl : _customerImageUrl;
    final icon = isFarmer ? Icons.agriculture : Icons.person;
    final title = isFarmer ? 'Farm Profile Image' : 'Profile Image';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: AppTextStyles.headline3),
        const SizedBox(height: 16),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: (_isUploadingImage || _isImagePickerActive)
                    ? null
                    : () {
                        if (!_isEditing) {
                          setState(() => _isEditing = true);
                        }
                        _uploadFarmerImage();
                      },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: Colors.grey[100]),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.grey[200],
                              child: Icon(icon, size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(icon, size: 50, color: Colors.grey),
                          ),
                  ),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: -5,
                  right: -5,
                  child: GestureDetector(
                    onTap: (_isUploadingImage || _isImagePickerActive)
                        ? null
                        : _uploadFarmerImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isUploadingImage
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: AppShimmerLoader(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(bool isFarmer) {
    final role = isFarmer ? 'Verified Farmer' : 'Premium Buyer';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFarmer
              ? [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.1),
                ]
              : [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.1)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFarmer ? AppColors.primary : Colors.blue,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFarmer ? AppColors.primary : Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isFarmer ? Icons.agriculture : Icons.shopping_bag,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isFarmer ? AppColors.primary : Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFarmer ? 'Manage your farm details' : 'Manage your account',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
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
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: !enabled,
        fillColor: !enabled ? Colors.grey[100] : null,
        labelStyle: enabled
            ? null
            : AppTextStyles.bodySmall.copyWith(color: Colors.grey[600]),
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
    );
  }

  Widget _buildActionButtons() {
    if (!_isEditing) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit),
          label: const Text('Edit Details'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
                                    if (dialogContext.mounted) { Navigator.of(dialogContext).pop(); }
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

