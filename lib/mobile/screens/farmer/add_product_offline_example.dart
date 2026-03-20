// ============================================================================
// lib/mobile/screens/farmer/add_product_offline_example.dart
// Farmer Add Product screen with offline-first support
// ============================================================================

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/product/category_model.dart';
import '../../../shared/models/product/unit_model.dart';
import '../../../shared/services/product/product_service.dart';
import '../../../shared/services/offline/offline_sync_service.dart';

class FarmerAddProductScreen extends StatefulWidget {
  const FarmerAddProductScreen({super.key});

  @override
  State<FarmerAddProductScreen> createState() => _FarmerAddProductScreenState();
}

class _FarmerAddProductScreenState extends State<FarmerAddProductScreen> {
  static const Color primary = Color(0xFF13EC5B);
  static const Color dark = Color(0xFF0F172A);

  final _productService = ProductService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _harvestDaysController = TextEditingController();

  List<Category> _categories = [];
  List<Unit> _units = [];
  Category? _selectedCategory;
  Unit? _selectedUnit;
  bool _isPreorder = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isOnline = true;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _initData();
    _productService.connectivityStream.listen((isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
    });
  }

  Future<void> _initData() async {
    try {
      final results = await Future.wait([
        _productService.getCategories(),
        _productService.getUnits(),
      ]);
      final isOnline = await OfflineSyncService().hasInternetConnection();
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _units = results[1] as List<Unit>;
          _isOnline = isOnline;
          _isInitializing = false;
        });
      }
    } catch (e) {
      // Log error and show user-friendly message
      print('Error loading categories/units: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories/units: $e')),
        );
        // Optionally navigate back
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
      imageQuality: 80,
    );
    if (file != null && mounted) setState(() => _imageFile = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category');
      return;
    }
    if (_selectedUnit == null) {
      _showSnackBar('Please select a unit');
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
      _showSnackBar('Failed to add product: $errorMsg');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_isOnline)
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Offline – product will sync when reconnected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(color: primary),
                    )
                  : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: dark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Add Product',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: dark,
            ),
          ),
          const Spacer(),
          if (!_isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildImagePicker(),
          const SizedBox(height: 20),

          _buildLabel('Product Name *'),
          const SizedBox(height: 6),
          _buildTextFormField(
            controller: _nameController,
            hint: 'e.g. Fresh Tomatoes',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Price (₱) *'),
                    const SizedBox(height: 6),
                    _buildTextFormField(
                      controller: _priceController,
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Quantity *'),
                    const SizedBox(height: 6),
                    _buildTextFormField(
                      controller: _quantityController,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildLabel('Category *'),
          const SizedBox(height: 6),
          _buildDropdown<Category>(
            value: _selectedCategory,
            hint: _categories.isEmpty
                ? 'No categories available'
                : 'Select category',
            items: _categories,
            displayLabel: (c) => c.name,
            onChanged: _categories.isEmpty
                ? null
                : (c) => setState(() => _selectedCategory = c),
          ),
          const SizedBox(height: 16),

          _buildLabel('Unit *'),
          const SizedBox(height: 6),
          _buildDropdown<Unit>(
            value: _selectedUnit,
            hint: _units.isEmpty ? 'No units available' : 'Select unit',
            items: _units,
            displayLabel: (u) => '${u.name} (${u.abbreviation})',
            onChanged: _units.isEmpty
                ? null
                : (u) => setState(() => _selectedUnit = u),
          ),
          const SizedBox(height: 16),

          _buildLabel('Days to Harvest'),
          const SizedBox(height: 6),
          _buildTextFormField(
            controller: _harvestDaysController,
            hint: 'Leave blank if already harvested',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          _buildLabel('Description'),
          const SizedBox(height: 6),
          _buildTextFormField(
            controller: _descriptionController,
            hint: 'Describe your product...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              value: _isPreorder,
              onChanged: (v) => setState(() => _isPreorder = v),
              title: Text(
                'Pre-order Product',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark,
                ),
              ),
              subtitle: Text(
                'Buyers can reserve before harvest',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              activeColor: primary,
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: dark,
                disabledBackgroundColor: primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(dark),
                      ),
                    )
                  : Text(
                      _isOnline ? 'Add Product' : 'Save Offline',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null ? primary : const Color(0xFFE2E8F0),
            width: _imageFile != null ? 2 : 1,
          ),
        ),
        child: _imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(io.File(_imageFile!.path), fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Product Photo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to upload from gallery',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF475569),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) displayLabel,
    required void Function(T?)? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(displayLabel(item)),
            ),
          )
          .toList(),
    );
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
}
