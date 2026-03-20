// ============================================================================
// lib/mobile/screens/farmer/modern_add_product_screen.dart
// Ultra-Modern Add Product Screen with Glassmorphism & Material 3 Design
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

class ModernAddProductScreen extends StatefulWidget {
  const ModernAddProductScreen({super.key});

  @override
  State<ModernAddProductScreen> createState() => _ModernAddProductScreenState();
}

class _ModernAddProductScreenState extends State<ModernAddProductScreen>
    with TickerProviderStateMixin {
  // Modern Color Palette - Light Theme (matching app design)
  static const Color primaryGreen = Color(0xFF13EC5B);
  static const Color primaryAccent = Color(0xFF0FD850);
  static const Color lightBg = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color surfaceBg = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  final _productService = ProductService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _harvestDaysController = TextEditingController();

  // Animation Controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

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
  bool _farmerApproved = true; // Assume approved by default
  String _farmerStatus = 'approved'; // approved, pending, pending_sync
  XFile? _imageFile;
  int _currentStep = 0; // 0: Basic, 1: Details, 2: Media & Tags, 3: Review

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initData();
    _productService.connectivityStream.listen((isOnline) {
      if (mounted) setState(() => _isOnline = isOnline);
    });
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
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
        _showErrorSnackBar('Failed to load data: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file != null && mounted) {
      setState(() => _imageFile = file);
      // Add haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _removeImage() {
    setState(() => _imageFile = null);
    HapticFeedback.selectionClick();
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
    HapticFeedback.selectionClick();
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

      await _productService.createProductOfflineFirst(
        name: _nameController.text.trim(),
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
        HapticFeedback.heavyImpact();
        String statusMsg;

        if (!_isOnline) {
          statusMsg = '📱 Product saved offline. Will sync when online.';
        } else if (_farmerStatus == 'pending') {
          statusMsg = '✅ Product added! Visible to you until registration approved.';
        } else {
          statusMsg = '✅ Product added successfully!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMsg),
            backgroundColor: success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to add product: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _slideController.forward().then((_) {
        setState(() => _currentStep++);
        _slideController.reverse();
      });
    } else {
      _submit();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _slideController.forward().then((_) {
        setState(() => _currentStep--);
        _slideController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: lightBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              children: [
                _buildModernHeader(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildAnimatedContent(),
                    ),
                  ),
                ),
                _buildFloatingFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryGreen.withOpacity(0.2), primaryAccent.withOpacity(0.3)],
                ),
              ),
              child: CircularProgressIndicator(
                color: primaryGreen,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading...',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    final stepTitles = ['Product Info', 'Pricing', 'Media & Tags', 'Review'];
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _buildGlassButton(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Product',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stepTitles[_currentStep],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isOnline) _buildOfflineBadge(),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warning.withOpacity(0.2),
        border: Border.all(color: warning.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: warning),
          const SizedBox(width: 6),
          Text(
            'OFFLINE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerStatusBanner() {
    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;
    String bannerMessage;

    switch (_farmerStatus) {
      case 'pending_sync':
        bannerColor = warning;
        bannerIcon = Icons.sync_outlined;
        bannerTitle = 'Registration Pending Sync';
        bannerMessage =
            'Your farmer registration will sync when you\'re back online. You can still add products - they\'ll be saved locally.';
        break;
      case 'pending':
        bannerColor = Colors.blue;
        bannerIcon = Icons.schedule_outlined;
        bannerTitle = 'Awaiting Admin Approval';
        bannerMessage =
            'Your registration is being reviewed. You can add products now - they\'ll be visible only to you until approved.';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        border: Border.all(color: bannerColor.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(bannerIcon, color: bannerColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bannerMessage,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: isActive
                  ? LinearGradient(colors: [primaryGreen, primaryAccent])
                  : null,
              color: isActive ? null : borderColor,
            ),
            child: isCompleted
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [success, primaryGreen]),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildAnimatedContent() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_slideAnimation.value, 0),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: _buildStepContent(),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0BasicInfo();
      case 1:
        return _buildStep1Details();
      case 2:
        return _buildStep2MediaAndTags();
      case 3:
        return _buildStep3Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep0BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        if (!_farmerApproved) _buildFarmerStatusBanner(),
        if (!_farmerApproved) const SizedBox(height: 20),
        _buildModernTextField(
          controller: _nameController,
          label: 'Product Name',
          hint: 'e.g., Fresh Organic Tomatoes',
          icon: Icons.inventory_2_outlined,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Product name is required' : null,
        ),
        const SizedBox(height: 24),
        _buildModernDropdown<Category>(
          label: 'Category',
          value: _selectedCategory,
          items: _categories,
          itemBuilder: (category) => category.name,
          onChanged: (category) => setState(() => _selectedCategory = category),
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 24),
        _buildModernDropdown<Unit>(
          label: 'Unit of Measure',
          value: _selectedUnit,
          items: _units,
          itemBuilder: (unit) => '${unit.name} (${unit.abbreviation})',
          onChanged: (unit) => setState(() => _selectedUnit = unit),
          icon: Icons.straighten_outlined,
        ),
        const SizedBox(height: 100), // Space for floating footer
      ],
    );
  }

  Widget _buildStep1Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _priceController,
                label: 'Price (₦)',
                hint: '0.00',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Price is required';
                  if (double.tryParse(value!) == null)
                    return 'Enter a valid price';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernTextField(
                controller: _quantityController,
                label: 'Quantity',
                hint: '0.00',
                icon: Icons.inventory_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Quantity is required';
                  if (double.tryParse(value!) == null)
                    return 'Enter a valid quantity';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildModernTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Tell customers about your product...',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        _buildPreorderToggle(),
        if (_isPreorder) ...[
          const SizedBox(height: 24),
          _buildModernTextField(
            controller: _harvestDaysController,
            label: 'Harvest Days',
            hint: 'Days until harvest',
            icon: Icons.schedule_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildStep2MediaAndTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionLabel('Product Image'),
        const SizedBox(height: 12),
        _imageFile == null
            ? _buildModernImagePicker()
            : _buildModernImagePreview(),
        const SizedBox(height: 32),
        _buildSectionLabel('Tags (Optional)'),
        const SizedBox(height: 12),
        _buildModernTagSelector(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildStep3Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionLabel('Review Product Details'),
        const SizedBox(height: 16),
        _buildModernReviewCard('Product Name', _nameController.text),
        _buildModernReviewCard('Category', _selectedCategory?.name ?? '—'),
        _buildModernReviewCard('Unit', _selectedUnit?.name ?? '—'),
        _buildModernReviewCard('Price', '₦${_priceController.text}'),
        _buildModernReviewCard(
          'Quantity',
          '${_quantityController.text} ${_selectedUnit?.abbreviation ?? ''}',
        ),
        if (_descriptionController.text.isNotEmpty)
          _buildModernReviewCard('Description', _descriptionController.text),
        if (_isPreorder)
          _buildModernReviewCard(
            'Harvest Days',
            '${_harvestDaysController.text} days',
          ),
        if (_selectedTagIds.isNotEmpty)
          _buildModernReviewCard(
            'Tags',
            _availableTags
                .where((t) => _selectedTagIds.contains(t.tagId))
                .map((t) => t.name)
                .join(', '),
          ),
        _buildModernReviewCard(
          'Image',
          _imageFile != null ? '✓ Image attached' : 'No image',
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: cardBg,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: textMuted),
              prefixIcon: Icon(icon, color: primaryGreen, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: cardBg,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  itemBuilder(item),
                  style: GoogleFonts.inter(color: textPrimary),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            dropdownColor: cardBg,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryGreen, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: GoogleFonts.inter(color: textPrimary),
            iconEnabledColor: primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildPreorderToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBg,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          Icons.schedule_outlined,
          color: primaryGreen,
          size: 24,
        ),
        title: Text(
          'Pre-order Product',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          'Product will be available after harvest',
          style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
        ),
        trailing: Switch(
          value: _isPreorder,
          onChanged: (value) {
            setState(() => _isPreorder = value);
            HapticFeedback.selectionClick();
          },
          activeColor: primaryGreen,
          activeTrackColor: primaryGreen.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildModernImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: surfaceBg,
          border: Border.all(color: primaryGreen.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryGreen.withOpacity(0.15),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 32,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Product Image',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to select from gallery',
              style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.file(
              io.File(_imageFile!.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _removeImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTagSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableTags.map((tag) {
        final isSelected = _selectedTagIds.contains(tag.tagId);
        return GestureDetector(
          onTap: () => _toggleTag(tag.tagId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: isSelected
                  ? LinearGradient(colors: [primaryGreen, primaryAccent])
                  : null,
              color: isSelected ? null : surfaceBg,
              border: Border.all(
                color: isSelected ? primaryGreen : borderColor,
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              tag.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? cardBg : textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernReviewCard(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBg,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: surfaceBg,
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }

  Widget _buildFloatingFooter() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: GestureDetector(
                  onTap: _previousStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _nextStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryGreen, primaryAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading && _currentStep == 3
                      ? SizedBox(
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(cardBg),
                          ),
                        )
                      : Text(
                          _currentStep == 3 ? 'Create Product' : 'Next',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cardBg,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
