import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/commerce/product_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/core/bootstrap_cache_service.dart';
import '../../../shared/services/offline/offline_product_service.dart';
import '../../../shared/services/offline/offline_queue_service.dart';
import '../../../shared/styles/app_theme.dart';
import '../../../shared/models/product/category_model.dart';
import '../../../shared/models/product/unit_model.dart';

/// Add Product Screen for Farmers with Offline Support
class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? editProduct;
  const AddProductScreen({super.key, this.editProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color primary = AppColors.primary;
  static const String _cachedCategoriesKey =
      BootstrapCacheService.cachedCategoriesKey;
  static const String _cachedUnitsKey = BootstrapCacheService.cachedUnitsKey;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _harvestDaysController = TextEditingController();
  final _quantityController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late OfflineProductService _offlineService;
  final Connectivity _connectivity = Connectivity();

  String? _selectedCategory;
  String? _selectedUnit;
  bool _isPreorder = false;
  bool _isLoading = false;
  bool _isLoadingDropdowns = true;
  bool _isOnline = true;

  final List<_PickedProductImage> _selectedImageFiles = [];

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _initializeOfflineService();
    _checkConnectivity();
    _listenToConnectivity();
    _loadCategoriesAndUnits();
    if (widget.editProduct != null) {
      _prefillFields();
    }
  }

  void _prefillFields() {
    final prod = widget.editProduct;
    if (prod == null) return;

    _nameController.text = prod['name']?.toString() ?? '';
    _priceController.text = prod['price']?.toString() ?? '';
    _descriptionController.text = prod['description']?.toString() ?? '';

    final avail = prod['available'] ?? prod['available_quantity'] ?? 0;
    _quantityController.text = (avail is num) ? avail.toInt().toString() : avail.toString();

    final hd = prod['harvest_days'] ?? 0;
    _harvestDaysController.text = (hd is num && hd > 0) ? hd.toString() : '';

    _isPreorder = prod['is_preorder'] == true;
    _selectedCategory = prod['category_id']?.toString();
    _selectedUnit = prod['unit_id']?.toString();

    final imagePath = prod['image']?.toString() ?? '';
    if (imagePath.isNotEmpty) {
      _selectedImageFiles.add(_PickedProductImage(
        name: 'existing_image.jpg',
        bytes: Uint8List(0),
        path: imagePath,
        isExisting: true,
      ));
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Product',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.editProduct!['name']}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSubtle, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleting products requires an active internet connection.')),
          );
          return;
        }
        await ProductService().deleteProduct(widget.editProduct!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete product: $e'), backgroundColor: Colors.red),
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
      setState(() => _isOnline = isOnline);

      if (isOnline && mounted) {
        _loadCategoriesAndUnits();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Back online! Syncing pending products...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        limit: 5,
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
            _PickedProductImage(name: imageName, bytes: bytes, path: file.path),
          );
        }
        setState(() {
          _selectedImageFiles.addAll(selectedImages);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
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

      if (widget.editProduct != null) {
        if (!_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Editing products requires an active internet connection.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        final client = SupabaseConfig.client;
        final productId = widget.editProduct!['id'];

        // 1. Update product table
        await client.from('products').update({
          'name': _nameController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'description': _descriptionController.text.trim(),
          'category_id': _selectedCategory,
          'unit_id': _selectedUnit,
          'harvest_days': _harvestDaysController.text.isNotEmpty
              ? int.parse(_harvestDaysController.text.trim())
              : 0,
          'is_preorder': _isPreorder,
        }).eq('product_id', productId);

        // 2. Update inventory table
        final qty = int.parse(
          _quantityController.text.trim().isEmpty
              ? '0'
              : _quantityController.text.trim(),
        );
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
        final newImages = _selectedImageFiles.where((img) => !img.isExisting).toList();
        if (newImages.isNotEmpty) {
          for (final img in newImages) {
            final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_${img.name}';
            final path = 'products/$fileName';
            await client.storage.from('uploads').uploadBinary(path, img.bytes);
            final publicUrl = client.storage.from('uploads').getPublicUrl(path);
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
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
        return;
      }

      // Get local image paths
      final localImagePaths = _selectedImageFiles
          .map((img) => img.path)
          .toList();

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
        price: double.parse(_priceController.text.trim()),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategory ?? '',
        unitId: _selectedUnit ?? '',
        harvestDays: _harvestDaysController.text.isNotEmpty
            ? int.parse(_harvestDaysController.text.trim())
            : 0,
        isPreorder: _isPreorder,
        availableQuantity: int.parse(
          _quantityController.text.trim().isEmpty
              ? '0'
              : _quantityController.text.trim(),
        ),
        localImagePaths: localImagePaths,
        webImageBytes: webImageBytes,
        webImageNames: webImageNames,
      );

      if (mounted) {
        String message = _isOnline
            ? 'Product added successfully!'
            : 'Product saved offline! Will sync when online.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _isOnline ? Colors.green : Colors.orange,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      debugPrint('🔵 Loading categories and units...');
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

      List<Category> categories = [];
      List<Unit> units = [];

      try {
        debugPrint('🔵 Fetching categories...');
        categories = await service.getCategories();
        debugPrint('✅ Categories loaded: ${categories.length}');
        for (var cat in categories) {
          debugPrint('   - ${cat.name} (${cat.categoryId})');
        }
      } catch (e) {
        debugPrint('❌ Failed to load categories: $e');
        rethrow;
      }

      try {
        debugPrint('🔵 Fetching units...');
        units = await service.getUnits();
        debugPrint('✅ Units loaded: ${units.length}');
        for (var unit in units) {
          debugPrint('   - ${unit.name} (${unit.unitId})');
        }
      } catch (e) {
        debugPrint('❌ Failed to load units: $e');
        rethrow;
      }

      if (mounted) {
        setState(() {
          _categories = categories
              .map((c) => {'id': c.categoryId, 'name': c.name})
              .toList();
          _units = units.map((u) => {'id': u.unitId, 'name': u.name}).toList();
          _isLoadingDropdowns = false;
        });
        await prefs.setString(_cachedCategoriesKey, jsonEncode(_categories));
        await prefs.setString(_cachedUnitsKey, jsonEncode(_units));
        debugPrint(
          '✅ Dropdowns populated with ${_categories.length} categories and ${_units.length} units',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading categories/units: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        if (cachedCategories.isNotEmpty && cachedUnits.isNotEmpty) {
          setState(() {
            _categories = cachedCategories;
            _units = cachedUnits;
            _isLoadingDropdowns = false;
          });
          return;
        }

        if (_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load categories/units.\n\n'
                'Make sure these tables exist in Supabase:\n'
                '- categories table with: id, name\n'
                '- units table with: id, name\n\n'
                'Error: $e',
              ),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
            ),
          );
        }
        setState(() {
          _isLoadingDropdowns = false;
        });
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
      debugPrint('Failed to read cached dropdown options: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _harvestDaysController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        title: Text(
          widget.editProduct != null ? 'Edit Product' : 'Add New Product',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.editProduct != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _isLoading ? null : _deleteProduct,
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isOnline ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: _isOnline ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isOnline
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormCard(
                    title: 'Media',
                    icon: Icons.photo_library_rounded,
                    child: _buildImagePicker(),
                  ),
                  const SizedBox(height: 20),
                  _buildFormCard(
                    title: 'Basic Information',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Product Name',
                          hint: 'e.g., Fresh Organic Tomatoes',
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Product name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'Highlight key details (organic, size, origin)...',
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFormCard(
                    title: 'Pricing & Category',
                    icon: Icons.sell_outlined,
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useStackedLayout = constraints.maxWidth < 360;

                            if (useStackedLayout) {
                              return Column(
                                children: [
                                  _buildTextField(
                                    controller: _priceController,
                                    label: 'Price',
                                    hint: '0.00',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    prefixIcon: Icons.sell_outlined,
                                    prefixText: '₱ ',
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDropdownField(
                                    label: 'Unit',
                                    value: _selectedUnit,
                                    items: _units,
                                    onChanged: (value) =>
                                        setState(() => _selectedUnit = value),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    controller: _priceController,
                                    label: 'Price',
                                    hint: '0.00',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    prefixIcon: Icons.sell_outlined,
                                    prefixText: '₱ ',
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdownField(
                                    label: 'Unit',
                                    value: _selectedUnit,
                                    items: _units,
                                    onChanged: (value) =>
                                        setState(() => _selectedUnit = value),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useStackedLayout = constraints.maxWidth < 360;

                            if (useStackedLayout) {
                              return Column(
                                children: [
                                  _buildTextField(
                                    controller: _quantityController,
                                    label: 'Available Quantity',
                                    hint: '0',
                                    keyboardType: TextInputType.number,
                                    prefixIcon: Icons.inventory_2_outlined,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      border: Border.all(color: Colors.grey[200]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Total Value',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _calculateTotalValue(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF13EC5B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _quantityController,
                                    label: 'Available Quantity',
                                    hint: '0',
                                    keyboardType: TextInputType.number,
                                    prefixIcon: Icons.inventory_2_outlined,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      border: Border.all(color: Colors.grey[200]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Total Value',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _calculateTotalValue(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF13EC5B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Category',
                          value: _selectedCategory,
                          items: _categories,
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFormCard(
                    title: 'Farming Details',
                    icon: Icons.eco_outlined,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _harvestDaysController,
                          label: 'Days to Harvest (Optional)',
                          hint: 'e.g., 30',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.calendar_month_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildCheckboxTile(
                          title: 'Pre-order Product',
                          subtitle: 'Allow customers to buy before harvest',
                          value: _isPreorder,
                          onChanged: (value) =>
                              setState(() => _isPreorder = value ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: primary.withValues(alpha: 0.5),
                        elevation: 4,
                        shadowColor: primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              widget.editProduct != null
                                  ? 'Save Changes'
                                  : (_isOnline
                                      ? 'Publish Product'
                                      : 'Save Offline & Publish Later'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Images',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_selectedImageFiles.length}/5',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedImageFiles.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImageFiles.length + 1,
              itemBuilder: (context, index) {
                if (index == _selectedImageFiles.length) {
                  if (_selectedImageFiles.length >= 5) {
                    return const SizedBox.shrink();
                  }

                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.1),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: primary,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _selectedImageFiles[index].isExisting
                            ? CachedNetworkImage(
                                imageUrl: _selectedImageFiles[index].path,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (_, _, _) => const Icon(Icons.error),
                              )
                            : Image.memory(
                                _selectedImageFiles[index].bytes,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImageFiles.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(
                  color: primary.withValues(alpha: 0.1),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      size: 32,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Product Images',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Up to 5 images (JPG or PNG)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[500], size: 20)
                : null,
            prefixText: prefixText,
            prefixStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 0,
            ),
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        _isLoadingDropdowns
            ? Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: AppShimmerLoader(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.grey[400]),
                    ),
                  ),
                ),
              )
            : items.isEmpty
            ? Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No $label available',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                initialValue: value,
                items: items.map((item) {
                  final displayText =
                      (item['name'] as String?) ??
                      (item['id'] as String?) ??
                      'Unknown';
                  final id = (item['id'] as String?) ?? '';
                  return DropdownMenuItem(value: id, child: Text(displayText));
                }).toList(),
                onChanged: onChanged,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey[500],
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: value
              ? primary.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? primary.withValues(alpha: 0.1) : Colors.grey[200]!,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
