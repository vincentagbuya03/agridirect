import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/bootstrap_cache_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/mascot/mascot_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';
import '../../../shared/services/offline/offline_queue_service.dart';

/// Add & Edit Product Screen for Farmers with Premium UI and Offline Support
class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? editProduct;
  const AddProductScreen({super.key, this.editProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color _primary = Color(0xFF059669);
  static const Color _textHeadline = Color(0xFF0F172A);
  static const Color _textSubtle = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _bgCard = Colors.white;

  static const String _cachedCategoriesKey =
      BootstrapCacheService.cachedCategoriesKey;
  static const String _cachedUnitsKey = BootstrapCacheService.cachedUnitsKey;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _harvestDaysController = TextEditingController();
  final _quantityController = TextEditingController();
  final _discountPercentController = TextEditingController(text: '30');
  final ImagePicker _imagePicker = ImagePicker();

  late OfflineProductService _offlineService;
  final Connectivity _connectivity = Connectivity();

  String? _selectedCategory;
  String? _selectedUnit;
  bool _isPreorder = false;
  bool _isFreeShipping = false;
  bool _isWholesale = false;
  bool _isFlashSale = false;
  DateTime? _flashSaleEndDate;
  String _flashDurationOption = '24_hours';
  bool _isLoading = false;
  bool _isLoadingDropdowns = true;
  bool _isOnline = true;

  final List<_PickedProductImage> _selectedImageFiles = [];

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];

  bool get _isEditMode => widget.editProduct != null;

  @override
  void initState() {
    super.initState();
    _initializeOfflineService();
    _checkConnectivity();
    _listenToConnectivity();
    _loadCategoriesAndUnits();
    if (_isEditMode) {
      _prefillFields();
    }
    _nameController.addListener(_onFormStateChanged);
    _priceController.addListener(_onFormStateChanged);
    _quantityController.addListener(_onFormStateChanged);
    _harvestDaysController.addListener(_onFormStateChanged);
  }

  void _onFormStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormStateChanged);
    _priceController.removeListener(_onFormStateChanged);
    _quantityController.removeListener(_onFormStateChanged);
    _harvestDaysController.removeListener(_onFormStateChanged);
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _harvestDaysController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _prefillFields() {
    final prod = widget.editProduct;
    if (prod == null) return;

    _nameController.text = prod['name']?.toString() ?? '';
    _priceController.text = prod['price']?.toString() ?? '';
    _descriptionController.text = prod['description']?.toString() ?? '';

    final avail = prod['available'] ?? prod['available_quantity'] ?? 0;
    _quantityController.text =
        (avail is num) ? avail.toInt().toString() : avail.toString();

    final hd = prod['harvest_days'] ?? 0;
    _harvestDaysController.text =
        (hd is num && hd > 0) ? hd.toString() : '';

    _isPreorder = prod['is_preorder'] == true;
    _isFreeShipping = prod['is_free_shipping'] == true;
    _isWholesale = prod['is_wholesale'] == true;
    _isFlashSale = prod['is_flash_sale'] == true;
    final disc = prod['discount_percent'] ?? prod['discount_percentage'];
    if (disc != null) {
      _discountPercentController.text = disc.toString();
    }
    _selectedCategory = prod['category_id']?.toString();
    _selectedUnit = prod['unit_id']?.toString();

    final imagePath = prod['image']?.toString() ?? '';
    if (imagePath.isNotEmpty) {
      _selectedImageFiles.add(
        _PickedProductImage(
          name: 'existing_image.jpg',
          bytes: Uint8List(0),
          path: imagePath,
          isExisting: true,
        ),
      );
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Product',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: _textHeadline,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.editProduct!['name']}"? This action cannot be undone.',
          style: GoogleFonts.inter(color: _textSubtle, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: _textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Deleting products requires an active internet connection.',
              ),
            ),
          );
          return;
        }
        await ProductService().deleteProduct(widget.editProduct!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeOfflineService() async {
    final queueService = OfflineQueueService();
    final productService = ProductService();
    _offlineService = OfflineProductService(
      queueService: queueService,
      productService: productService,
      connectivity: _connectivity,
    );
    await _offlineService.init();
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
    });
  }

  void _listenToConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final isOnline =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      final wasOffline = !_isOnline;

      setState(() => _isOnline = isOnline);

      if (isOnline && wasOffline && mounted) {
        _loadCategoriesAndUnits();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Back online! Syncing pending products...'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _pickImageSource(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final file = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (file != null) {
          final bytes = await file.readAsBytes();
          final imageName = file.name.isNotEmpty
              ? file.name
              : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
          setState(() {
            _selectedImageFiles.add(
              _PickedProductImage(
                name: imageName,
                bytes: bytes,
                path: file.path,
              ),
            );
          });
        }
      } else {
        final pickedFiles = await _imagePicker.pickMultiImage(
          limit: 5 - _selectedImageFiles.length,
          imageQuality: 85,
        );
        if (pickedFiles.isNotEmpty) {
          final selectedImages = <_PickedProductImage>[];
          for (final file in pickedFiles) {
            final bytes = await file.readAsBytes();
            final imageName = file.name.isNotEmpty
                ? file.name
                : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
            selectedImages.add(
              _PickedProductImage(
                name: imageName,
                bytes: bytes,
                path: file.path,
              ),
            );
          }
          setState(() {
            _selectedImageFiles.addAll(selectedImages);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category and unit')),
      );
      return;
    }

    if (_selectedImageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 image')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.currentUser?.id ?? '';

      if (_isEditMode) {
        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Editing products requires an active internet connection.',
              ),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        final client = SupabaseConfig.client;
        final productId = widget.editProduct!['id'];

        // 1. Update product table
        await client.from('products').update({
          'name': _nameController.text.trim(),
          'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
          'description': _descriptionController.text.trim(),
          'category_id': _selectedCategory,
          'unit_id': _selectedUnit,
          'harvest_days': _harvestDaysController.text.isNotEmpty
              ? (double.tryParse(_harvestDaysController.text.trim())
                      ?.toInt() ??
                  0)
              : 0,
          'is_preorder': _isPreorder,
          'is_free_shipping': _isFreeShipping,
          'is_wholesale': _isWholesale,
          'is_flash_sale': _isFlashSale,
          'discount_percent': _isFlashSale
              ? double.tryParse(_discountPercentController.text.trim()) ?? 30.0
              : null,
          if (_isFlashSale) 'flash_sale_start': DateTime.now().toIso8601String(),
          if (_isFlashSale)
            'flash_sale_end': (_flashDurationOption == 'midnight'
                    ? DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day + 1,
                      )
                    : (_flashDurationOption == '3_days'
                        ? DateTime.now().add(const Duration(days: 3))
                        : (_flashDurationOption == '7_days'
                            ? DateTime.now().add(const Duration(days: 7))
                            : (_flashSaleEndDate ??
                                DateTime.now().add(const Duration(hours: 24))))))
                .toIso8601String(),
        }).eq('product_id', productId);

        // 2. Update inventory table
        final qty = double.tryParse(
          _quantityController.text.trim().isEmpty
              ? '0'
              : _quantityController.text.trim(),
        )?.toInt() ?? 0;
        await client.from('product_inventory').upsert({
          'product_id': productId,
          'available_quantity': qty,
        }, onConflict: 'product_id');

        // 2.5. Delete removed images from product_images table
        final currentDbImages = await client
            .from('product_images')
            .select('image_id, image_url')
            .eq('product_id', productId);

        final remainingExistingPaths = _selectedImageFiles
            .where((img) => img.isExisting)
            .map((img) => img.path)
            .toList();

        for (final dbImg in currentDbImages) {
          final dbUrl = dbImg['image_url']?.toString();
          if (dbUrl != null && !remainingExistingPaths.contains(dbUrl)) {
            await client
                .from('product_images')
                .delete()
                .eq('image_id', dbImg['image_id']);
          }
        }

        // 3. Upload new images and save to product_images table if selected
        final newImages =
            _selectedImageFiles.where((img) => !img.isExisting).toList();
        if (newImages.isNotEmpty) {
          for (final img in newImages) {
            final fileName =
                'product_${DateTime.now().millisecondsSinceEpoch}_${img.name}';
            final path = 'products/$fileName';
            await client.storage.from('uploads').uploadBinary(path, img.bytes);
            final publicUrl =
                client.storage.from('uploads').getPublicUrl(path);
            await client.from('product_images').insert({
              'product_id': productId,
              'image_url': publicUrl,
              'sort_order': 0,
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          context.pop(true);
        }
        return;
      }

      // Get local image paths
      final localImagePaths =
          _selectedImageFiles.map((img) => img.path).toList();

      final webImageBytes = kIsWeb
          ? _selectedImageFiles.map((img) => img.bytes).toList()
          : null;
      final webImageNames = kIsWeb
          ? _selectedImageFiles.map((img) => img.name).toList()
          : null;

      // Use offline service to save
      await _offlineService.createProduct(
        farmerId: userId,
        name: _nameController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategory ?? '',
        unitId: _selectedUnit ?? '',
        harvestDays: _harvestDaysController.text.isNotEmpty
            ? (double.tryParse(_harvestDaysController.text.trim())?.toInt() ?? 0)
            : 0,
        isPreorder: _isPreorder,
        availableQuantity: double.tryParse(
          _quantityController.text.trim().isEmpty
              ? '0'
              : _quantityController.text.trim(),
        )?.toInt() ?? 0,
        localImagePaths: localImagePaths,
        webImageBytes: webImageBytes,
        webImageNames: webImageNames,
        isFreeShipping: _isFreeShipping,
        isWholesale: _isWholesale,
        isFlashSale: _isFlashSale,
      );

      if (mounted) {
        String message = _isOnline
            ? 'Product added successfully!'
            : 'Product saved offline! Will sync when online.';

        MascotService.showCelebration(
          context,
          message: message,
          onDismiss: () => context.pop(true),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCategoriesAndUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCategories = _readCachedOptions(
      prefs.getString(_cachedCategoriesKey),
    );
    final cachedUnits = _readCachedOptions(prefs.getString(_cachedUnitsKey));

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final currentlyOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (mounted && _isOnline != currentlyOnline) {
        setState(() => _isOnline = currentlyOnline);
      }

      final service = ProductService();

      if (!currentlyOnline) {
        if (cachedCategories.isNotEmpty && cachedUnits.isNotEmpty) {
          if (mounted) {
            setState(() {
              _categories = cachedCategories;
              _units = cachedUnits;
              _isLoadingDropdowns = false;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoadingDropdowns = false;
            _categories = [];
            _units = [];
          });
        }
        return;
      }

      final categories = await service.getCategories();
      final units = await service.getUnits();

      if (mounted) {
        setState(() {
          _categories = categories
              .map<Map<String, dynamic>>(
                (c) => {'id': c.categoryId, 'name': c.name},
              )
              .toList();
          _units = units
              .map<Map<String, dynamic>>(
                (u) => {'id': u.unitId, 'name': u.name},
              )
              .toList();
          _isLoadingDropdowns = false;
        });
        await prefs.setString(_cachedCategoriesKey, jsonEncode(_categories));
        await prefs.setString(_cachedUnitsKey, jsonEncode(_units));
      }
    } catch (e) {
      if (mounted) {
        if (cachedCategories.isNotEmpty && cachedUnits.isNotEmpty) {
          setState(() {
            _categories = cachedCategories;
            _units = cachedUnits;
            _isLoadingDropdowns = false;
          });
          return;
        }
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  List<Map<String, dynamic>> _readCachedOptions(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _textHeadline,
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditMode ? 'Edit Product' : 'Add New Product',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textHeadline,
              ),
            ),
            Text(
              _isEditMode
                  ? 'Update listing details & pricing'
                  : 'List fresh produce to the marketplace',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _textSubtle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Online / Offline Status Chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFF97316).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: _isOnline
                          ? const Color(0xFF059669)
                          : const Color(0xFFF97316),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isOnline
                            ? const Color(0xFF059669)
                            : const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
              onPressed: _isLoading ? null : _deleteProduct,
              tooltip: 'Delete Product',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWidescreen = constraints.maxWidth >= 900;
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isWidescreen ? 32 : 16,
                        vertical: 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isWidescreen ? 1100 : 640,
                          ),
                          child: isWidescreen
                              ? _buildDesktopLayout()
                              : _buildMobileLayout(),
                        ),
                      ),
                    ),
                  ),
                  _buildBottomActionBar(isWidescreen),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMediaSection(),
        const SizedBox(height: 16),
        _buildBasicInfoSection(),
        const SizedBox(height: 16),
        _buildPricingSection(),
        const SizedBox(height: 16),
        _buildPromotionsSection(),
        const SizedBox(height: 16),
        _buildFarmingDetailsSection(),
        const SizedBox(height: 16),
        _buildLivePreviewCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildMediaSection(),
              const SizedBox(height: 20),
              _buildLivePreviewCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 20),
              _buildPricingSection(),
              const SizedBox(height: 20),
              _buildPromotionsSection(),
              const SizedBox(height: 20),
              _buildFarmingDetailsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 1. Media Upload Section ───
  Widget _buildMediaSection() {
    return _buildSectionCard(
      title: 'Product Photos',
      subtitle: 'Upload up to 5 clear photos. First photo is the main cover.',
      icon: Icons.photo_library_rounded,
      badge: '${_selectedImageFiles.length}/5',
      child: Column(
        children: [
          if (_selectedImageFiles.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _selectedImageFiles.length +
                    (_selectedImageFiles.length < 5 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _selectedImageFiles.length) {
                    return _buildAddMorePhotoButton();
                  }

                  final item = _selectedImageFiles[index];
                  final isMain = index == 0;

                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item.isExisting
                              ? CachedNetworkImage(
                                  imageUrl: item.path,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: _textSubtle,
                                    ),
                                  ),
                                )
                              : Image.memory(item.bytes, fit: BoxFit.cover),
                        ),
                        // Main Cover Badge
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isMain
                                  ? _primary
                                  : Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMain ? 'COVER' : '#${index + 1}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        // Delete Button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImageFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            _buildEmptyPhotoUploader(),
        ],
      ),
    );
  }

  Widget _buildEmptyPhotoUploader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo_rounded,
              color: _primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Upload Fresh Produce Photos',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textHeadline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'High quality photos increase buyer trust and orders.',
            style: GoogleFonts.inter(fontSize: 12, color: _textSubtle),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImageSource(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImageSource(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddMorePhotoButton() {
    return GestureDetector(
      onTap: () => _pickImageSource(ImageSource.gallery),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCBD5E1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_rounded, color: _primary, size: 24),
            const SizedBox(height: 4),
            Text(
              'Add More',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Basic Information Section ───
  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Basic Information',
      subtitle: 'Name your product and choose its marketplace category',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _buildStyledTextField(
            controller: _nameController,
            label: 'Product / Crop Name',
            hint: 'e.g., Fresh Organic Native Tomatoes',
            prefixIcon: Icons.grass_rounded,
            validator: (value) =>
                value?.trim().isEmpty ?? true ? 'Product name is required' : null,
          ),
          const SizedBox(height: 14),
          _buildCategoryDropdown(),
          const SizedBox(height: 14),
          _buildStyledTextField(
            controller: _descriptionController,
            label: 'Description & Origin (Optional)',
            hint: 'Describe farming practices (organic, pesticide-free), taste profile, harvest origin...',
            maxLines: 3,
            prefixIcon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }

  // ─── 3. Pricing & Inventory Section ───
  Widget _buildPricingSection() {
    return _buildSectionCard(
      title: 'Pricing & Inventory',
      subtitle: 'Set unit pricing and current stock availability',
      icon: Icons.sell_outlined,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildStyledTextField(
                  controller: _priceController,
                  label: 'Price per Unit',
                  hint: '0.00',
                  prefixText: '₱ ',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildUnitDropdown(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildStyledTextField(
                  controller: _quantityController,
                  label: 'Available Stock',
                  hint: 'e.g., 50',
                  prefixIcon: Icons.inventory_2_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Dynamic Total Value Pill
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Inventory Value',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _textHeadline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _calculateTotalValue(),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. Promotions & Marketplace Features (Replaces Grey Checkboxes) ───
  Widget _buildPromotionsSection() {
    return _buildSectionCard(
      title: 'Marketplace Features & Promotions',
      subtitle: 'Attract more buyers and enable bulk or seasonal discounts',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          _buildFeatureToggleTile(
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFF0284C7),
            title: 'Free Shipping',
            subtitle: 'Cover delivery costs to attract 3x more consumer orders',
            value: _isFreeShipping,
            onChanged: (val) => setState(() => _isFreeShipping = val),
          ),
          const SizedBox(height: 10),
          _buildFeatureToggleTile(
            icon: Icons.storefront_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: 'Wholesale Pricing',
            subtitle: 'Offer volume discounts for restaurants, bulk buyers & vendors',
            value: _isWholesale,
            onChanged: (val) => setState(() => _isWholesale = val),
          ),
          const SizedBox(height: 10),
          _buildFeatureToggleTile(
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFEA580C),
            title: 'Flash Sale Nomination',
            subtitle: 'Spotlight this item in seasonal and weekend flash deals',
            value: _isFlashSale,
            onChanged: (val) => setState(() => _isFlashSale = val),
          ),
          if (_isFlashSale) ...[
            const SizedBox(height: 10),
            _buildStyledTextField(
              controller: _discountPercentController,
              label: 'Flash Sale Discount Percentage (%)',
              hint: 'e.g., 35',
              prefixIcon: Icons.percent_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Countdown Duration',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildAddProdDurationChip('Midnight', 'midnight'),
                _buildAddProdDurationChip('24 Hours', '24_hours'),
                _buildAddProdDurationChip('3 Days', '3_days'),
                _buildAddProdDurationChip('7 Days', '7_days'),
                _buildAddProdDurationChip('Custom Date', 'custom'),
              ],
            ),
            if (_flashDurationOption == 'custom') ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _flashSaleEndDate ??
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() {
                      _flashSaleEndDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        23,
                        59,
                        59,
                      );
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Text(
                        _flashSaleEndDate != null
                            ? 'Ends: ${_flashSaleEndDate!.month}/${_flashSaleEndDate!.day}/${_flashSaleEndDate!.year}'
                            : 'Pick Custom End Date',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── 5. Farming & Pre-order Details ───
  Widget _buildFarmingDetailsSection() {
    return _buildSectionCard(
      title: 'Harvest & Pre-order Details',
      subtitle: 'Schedule upcoming harvests and accept advance customer reservations',
      icon: Icons.eco_outlined,
      child: Column(
        children: [
          _buildStyledTextField(
            controller: _harvestDaysController,
            label: 'Estimated Days to Harvest (Optional)',
            hint: 'e.g., 14',
            prefixIcon: Icons.calendar_month_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildFeatureToggleTile(
            icon: Icons.grass_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Enable Pre-order for this Crop',
            subtitle: 'Allow buyers to reserve and pay in advance before harvest date',
            value: _isPreorder,
            onChanged: (val) => setState(() => _isPreorder = val),
          ),
          if (_isPreorder) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF059669),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pre-orders let you post growth updates (🌱 sprouting, flowering, harvest) to build excitement with reserving buyers!',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: const Color(0xFF065F46),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 6. Live Marketplace Buyer Preview ───
  Widget _buildLivePreviewCard() {
    final name = _nameController.text.trim().isEmpty
        ? 'Fresh Farm Produce'
        : _nameController.text.trim();
    final priceText = _priceController.text.trim().isEmpty
        ? '0.00'
        : _priceController.text.trim();
    final qty = _quantityController.text.trim();

    String categoryName = 'Produce';
    if (_selectedCategory != null) {
      final cat = _categories.firstWhere(
        (c) => c['id']?.toString() == _selectedCategory,
        orElse: () => <String, dynamic>{},
      );
      if (cat['name'] != null) categoryName = cat['name'].toString();
    }

    String unitName = 'kg';
    if (_selectedUnit != null) {
      final u = _units.firstWhere(
        (un) => un['id']?.toString() == _selectedUnit,
        orElse: () => <String, dynamic>{},
      );
      if (u['name'] != null) unitName = u['name'].toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: _primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Marketplace Live Preview',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _textHeadline,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'BUYER VIEW',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: _selectedImageFiles.isNotEmpty
                        ? (_selectedImageFiles.first.isExisting
                            ? CachedNetworkImage(
                                imageUrl: _selectedImageFiles.first.path,
                                fit: BoxFit.cover,
                              )
                            : Image.memory(
                                _selectedImageFiles.first.bytes,
                                fit: BoxFit.cover,
                              ))
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.agriculture_rounded,
                              color: Color(0xFF94A3B8),
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Preview Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textHeadline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₱$priceText',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                          Text(
                            ' / $unitName',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _textSubtle,
                            ),
                          ),
                          const Spacer(),
                          if (_isPreorder)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'PRE-ORDER',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0284C7),
                                ),
                              ),
                            )
                          else if (qty.isNotEmpty)
                            Text(
                              '$qty in stock',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _textSubtle,
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
        ],
      ),
    );
  }

  // ─── 7. Sticky Bottom Action Bar ───
  Widget _buildBottomActionBar(bool isWidescreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWidescreen ? 32 : 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWidescreen ? 1100 : 640),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 17,
                        ),
                  label: Text(
                    _isEditMode
                        ? 'Save Changes'
                        : (_isOnline ? 'Publish Product' : 'Save Offline'),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Card Wrapper ───
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _textHeadline,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: _textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ─── Interactive Feature Toggle Tile (Replaces dated checkboxes) ───
  Widget _buildFeatureToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : _borderColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _textHeadline,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _textSubtle,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: _primary,
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textHeadline,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _textHeadline,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 18)
                : null,
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(
              color: _primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 12 : 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final validValue =
        _categories.any((item) => (item['id'] as String?) == _selectedCategory)
            ? _selectedCategory
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Category',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textHeadline,
          ),
        ),
        const SizedBox(height: 6),
        _isLoadingDropdowns
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                initialValue: validValue,
                items: _categories.map((item) {
                  final displayText = (item['name'] as String?) ?? 'Produce';
                  final id = (item['id'] as String?) ?? '';
                  return DropdownMenuItem(
                    value: id,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(
                    Icons.category_outlined,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _textHeadline,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Category is required' : null,
              ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    final validValue =
        _units.any((item) => (item['id'] as String?) == _selectedUnit)
            ? _selectedUnit
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textHeadline,
          ),
        ),
        const SizedBox(height: 6),
        _isLoadingDropdowns
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                initialValue: validValue,
                items: _units.map((item) {
                  final displayText = (item['name'] as String?) ?? 'kg';
                  final id = (item['id'] as String?) ?? '';
                  return DropdownMenuItem(
                    value: id,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedUnit = val),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _textHeadline,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Unit is required' : null,
              ),
      ],
    );
  }

  Widget _buildAddProdDurationChip(String label, String value) {
    final isSelected = _flashDurationOption == value;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFDC2626),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _flashDurationOption = value;
          });
        }
      },
    );
  }

  String _calculateTotalValue() {
    try {
      final price = double.tryParse(_priceController.text) ?? 0;
      final quantity = double.tryParse(_quantityController.text) ?? 0;
      final total = price * quantity;
      return '₱${total.toStringAsFixed(2)}';
    } catch (e) {
      return '₱0.00';
    }
  }
}

class _PickedProductImage {
  final String name;
  final Uint8List bytes;
  final String path;
  final bool isExisting;

  const _PickedProductImage({
    required this.name,
    required this.bytes,
    required this.path,
    this.isExisting = false,
  });
}
