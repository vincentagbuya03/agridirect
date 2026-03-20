// ============================================================================
// lib/mobile/screens/farmer/add_product_screen_improved.dart
// Improved Farmer Add Product screen with offline-first + tags + better UI
// ============================================================================

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/product/category_model.dart';
import '../../../shared/models/product/unit_model.dart';
import '../../../shared/models/product/tag_model.dart';
import '../../../shared/services/product/product_service.dart';
import '../../../shared/services/offline/offline_sync_service.dart';

class ImprovedFarmerAddProductScreen extends StatefulWidget {
  const ImprovedFarmerAddProductScreen({super.key});

  @override
  State<ImprovedFarmerAddProductScreen> createState() =>
      _ImprovedFarmerAddProductScreenState();
}

class _ImprovedFarmerAddProductScreenState
    extends State<ImprovedFarmerAddProductScreen> {
  static const Color primary = Color(0xFF13EC5B);
  static const Color dark = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color lightBg = Color(0xFFF7FAF7);
  static const Color cardBg = Colors.white;

  final _productService = ProductService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _harvestDaysController = TextEditingController();

  // State variables
  List<Category> _categories = [];
  List<Unit> _units = [];
  List<Tag> _availableTags = [];
  Category? _selectedCategory;
  Unit? _selectedUnit;
  Set<String> _selectedTagIds = {};
  bool _isPreorder = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isOnline = true;
  XFile? _imageFile;
  int _currentStep =
      0; // Step 0: Basic, Step 1: Details, Step 2: Tags & Image, Step 3: Review

  @override
  void initState() {
    super.initState();
    _initData();
    _productService.connectivityStream.listen((isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _harvestDaysController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final results = await Future.wait([
        _productService.getCategories(),
        _productService.getUnits(),
        _productService.getTags(),
      ]);
      final isOnline = await OfflineSyncService().hasInternetConnection();
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _units = results[1] as List<Unit>;
          _availableTags = results[2] as List<Tag>;
          _isOnline = isOnline;
          _isInitializing = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        _showErrorSnackBar('Failed to load categories/units/tags: $e');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (file != null && mounted) setState(() => _imageFile = file);
  }

  Future<void> _removeImage() async {
    if (mounted) setState(() => _imageFile = null);
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }
    if (_selectedUnit == null) {
      _showErrorSnackBar('Please select a unit');
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? imageBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final productName = _nameController.text.trim();
      await _productService.createProductOfflineFirst(
        name: productName,
        price: double.parse(_priceController.text),
        categoryId: _selectedCategory!.categoryId,
        unitId: _selectedUnit!.unitId,
        quantity: double.parse(_quantityController.text),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageBase64: imageBase64,
        harvestDays: _harvestDaysController.text.isEmpty
            ? null
            : int.tryParse(_harvestDaysController.text),
        isPreorder: _isPreorder,
        tagIds: _selectedTagIds.toList(),
      );

      if (mounted) {
        final statusMsg = _isOnline
            ? '✅ Product added! Syncing to server...'
            : '📱 Product saved locally. Will sync when online.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMsg),
            backgroundColor: primary,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      final errorMsg = e.toString();
      print('❌ Error adding product: $errorMsg');
      _showErrorSnackBar('Failed to add product: $errorMsg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: lightBg,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = ['Basic Info', 'Details', 'Tags & Image', 'Review'];
    return Container(
      color: cardBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Back button and title
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_rounded, size: 20, color: dark),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Product',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: dark,
                      ),
                    ),
                    Text(
                      stepTitles[_currentStep],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 12,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'OFFLINE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              minHeight: 4,
              backgroundColor: lightBg,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0BasicInfo();
      case 1:
        return _buildStep1Details();
      case 2:
        return _buildStep2TagsAndImage();
      case 3:
        return _buildStep3Review();
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildStep0BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Product Name'),
        _buildTextField(
          controller: _nameController,
          hint: 'e.g., Fresh Tomatoes',
          validator: (value) =>
              value?.isEmpty ?? true ? 'Product name is required' : null,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Category'),
        _buildCategoryDropdown(),
        const SizedBox(height: 20),
        _buildSectionTitle('Select Unit'),
        _buildUnitDropdown(),
      ],
    );
  }

  Widget _buildStep1Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Price (₦)'),
        _buildTextField(
          controller: _priceController,
          hint: '0.00',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Price is required';
            if (double.tryParse(value!) == null) return 'Enter a valid price';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Quantity Available'),
        _buildTextField(
          controller: _quantityController,
          hint: '0.00',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Quantity is required';
            if (double.tryParse(value!) == null)
              return 'Enter a valid quantity';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Description (Optional)'),
        _buildTextField(
          controller: _descriptionController,
          hint: 'Describe your product...',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildStep2TagsAndImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Tags (Optional)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTags.map((tag) {
            final isSelected = _selectedTagIds.contains(tag.tagId);
            return GestureDetector(
              onTap: () => _toggleTag(tag.tagId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primary : lightBg,
                  border: Border.all(
                    color: isSelected ? primary : muted.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? dark : muted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Product Image'),
        _imageFile == null ? _buildImagePicker() : _buildImagePreview(),
      ],
    );
  }

  Widget _buildStep3Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Review Your Product'),
        _buildReviewCard(
          label: 'Name',
          value: _nameController.text.isNotEmpty ? _nameController.text : '—',
        ),
        _buildReviewCard(
          label: 'Category',
          value: _selectedCategory?.name ?? '—',
        ),
        _buildReviewCard(label: 'Unit', value: _selectedUnit?.name ?? '—'),
        _buildReviewCard(
          label: 'Price',
          value: _priceController.text.isNotEmpty
              ? '₦${_priceController.text}'
              : '—',
        ),
        _buildReviewCard(
          label: 'Quantity',
          value: _quantityController.text.isNotEmpty
              ? '${_quantityController.text} ${_selectedUnit?.abbreviation ?? ''}'
              : '—',
        ),
        if (_descriptionController.text.isNotEmpty)
          _buildReviewCard(
            label: 'Description',
            value: _descriptionController.text,
          ),
        if (_selectedTagIds.isNotEmpty)
          _buildReviewCard(
            label: 'Tags',
            value: _availableTags
                .where((t) => _selectedTagIds.contains(t.tagId))
                .map((t) => t.name)
                .join(', '),
          ),
        _buildReviewCard(
          label: 'Image',
          value: _imageFile != null ? '✓ Image attached' : 'No image',
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: lightBg,
          border: Border.all(color: primary.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 40, color: primary),
            const SizedBox(height: 8),
            Text(
              'Tap to select image',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPEG, PNG (Max 5MB)',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(io.File(_imageFile!.path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: dark,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: muted),
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<Category>(
      value: _selectedCategory,
      items: _categories.map((cat) {
        return DropdownMenuItem(
          value: cat,
          child: Text(cat.name, style: GoogleFonts.plusJakartaSans()),
        );
      }).toList(),
      onChanged: (category) => setState(() => _selectedCategory = category),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (_) =>
          _selectedCategory == null ? 'Please select a category' : null,
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<Unit>(
      value: _selectedUnit,
      items: _units.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(
            '${unit.name} (${unit.abbreviation})',
            style: GoogleFonts.plusJakartaSans(),
          ),
        );
      }).toList(),
      onChanged: (unit) => setState(() => _selectedUnit = unit),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: muted.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (_) => _selectedUnit == null ? 'Please select a unit' : null,
    );
  }

  Widget _buildReviewCard({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dark,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _currentStep--),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: lightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Back',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark,
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      if (_currentStep < 3) {
                        setState(() => _currentStep++);
                      } else {
                        _submit();
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLoading && _currentStep == 3
                    ? SizedBox(
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(dark),
                        ),
                      )
                    : Text(
                        _currentStep == 3 ? 'Submit' : 'Next',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dark,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
