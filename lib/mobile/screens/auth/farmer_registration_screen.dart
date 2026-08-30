import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/models/farmer_registration.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/services/integration/reverse_geocoding_service.dart';
import 'dart:convert';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/auth/verification_guide_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:agridirect/mobile/screens/common/id_back_scanner.dart';
import 'package:agridirect/mobile/screens/common/id_capture_screen.dart';

class FarmerRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const FarmerRegistrationScreen({
    super.key,
    required this.onRegistrationComplete,
  });

  @override
  State<FarmerRegistrationScreen> createState() =>
      _FarmerRegistrationScreenState();
}

class _FarmerRegistrationScreenState extends State<FarmerRegistrationScreen> {
  static const Color _primary = Color(0xFF10B981); // Emerald Green
  static const Color _accent = Color(0xFF34D399); // Light Emerald
  static const Color _dark = Color(0xFF0F172A); // Slate 900
  static const Color _muted = Color(0xFF64748B); // Slate 500
  static const Color _border = Color(0xFFE2E8F0); // Slate 200
  static const Color _surface = Color(0xFFF8FAFC); // Slate 50

  int _currentStep = 0;
  bool _isSubmitting = false;
  final _registration = FarmerRegistration();

  final _fullNameController = TextEditingController();
  final _sexController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _pcnController = TextEditingController();

  // Step 1 controllers
  final _birthDateController = TextEditingController();
  final _yearsController = TextEditingController();
  final _addressController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _livestockController = TextEditingController();
  final Set<String> _selectedCrops = {'Rice'};
  final Set<String> _selectedLivestock = {'Swine'};
  double? _farmLatitude;
  double? _farmLongitude;
  String _resolvedFarmLocation = '';

  // Step 3 controllers
  final _elementaryController = TextEditingController();
  final _highSchoolController = TextEditingController();
  final _collegeController = TextEditingController();
  final _farmingHistoryController = TextEditingController();
  bool _certificationAccepted = false;

  // Step 2 state (Now Step 0)
  String _idType = 'national_id'; // or 'local_id'
  bool _faceScanned = false;
  String? _faceImagePath;
  Uint8List? _faceImageBytes;
  bool _idUploaded = false; // ID Front
  String? _idImagePath;
  Uint8List? _idImageBytes;
  bool _idBackUploaded = false; // ID Back Captured
  String? _idBackImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  // Signature
  bool _guideShown = false;
  bool _isClosingSuccessDialog = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _sexController.dispose();
    _placeOfBirthController.dispose();
    _pcnController.dispose();
    _birthDateController.dispose();
    _yearsController.dispose();
    _addressController.dispose();
    _farmNameController.dispose();
    _specialtyController.dispose();
    _livestockController.dispose();
    _elementaryController.dispose();
    _highSchoolController.dispose();
    _collegeController.dispose();
    _farmingHistoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative Background elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: _buildCurrentStep(),
                  ),
                ),
                _buildBottomButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Bar ───
  Widget _buildTopBar() {
    final titles = [
      'Identity Verification',
      'Farm & Personal Data',
      'Experience & Review',
    ];

    final subtitles = [
      'KYC biometric & government ID verification',
      'Complete your profile and farm portfolio',
      'Review background and submit application',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _dark,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titles[_currentStep],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitles[_currentStep],
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quick Verification Guide Button in Top Bar
              if (_currentStep == 0)
                GestureDetector(
                  onTap: _showVerificationGuide,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Guide',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ───
  Widget _buildStepIndicator() {
    final labels = ['Verification', 'Profile & Farm', 'Review'];
    final icons = [Icons.shield_outlined, Icons.person_outline_rounded, Icons.rate_review_outlined];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              final isCompleted = i < _currentStep;
              final isCurrent = i == _currentStep;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCurrent || isCompleted ? _primary : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle_rounded : icons[i],
                            size: 12,
                            color: isCurrent ? _primary : (isCompleted ? const Color(0xFF16A34A) : _muted),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              labels[i],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrent ? _dark : _muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentStep),
        child: _getStepWidget(),
      ),
    );
  }

  Widget _getStepWidget() {
    if (_currentStep == 0 && !_guideShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_guideShown) {
          _showVerificationGuide();
          setState(() => _guideShown = true);
        }
      });
    }

    switch (_currentStep) {
      case 0:
        return _buildStep2();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════
  // STEP 1: Personal Data & Farm Details
  // ═══════════════════════════════════════════
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ─── Scanned ID Reference Card ───
        if (_idImagePath != null ||
            _idBackImagePath != null ||
            _faceImagePath != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary.withValues(alpha: 0.08), Colors.white],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Color(0xFF16A34A),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scanned ID Reference',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tap to inspect',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Use your scanned ID photos to verify and complete your profile data.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: _muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_faceImagePath != null) ...[
                      _buildScannedThumb(
                        'Selfie',
                        _faceImagePath!,
                        () => _showImagePreviewDialog(
                          _faceImagePath!,
                          'Facial Biometric Selfie',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_idImagePath != null) ...[
                      _buildScannedThumb(
                        'ID Front',
                        _idImagePath!,
                        () => _showImagePreviewDialog(
                          _idImagePath!,
                          'ID Front Photo',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_idBackImagePath != null) ...[
                      _buildScannedThumb(
                        'ID Back',
                        _idBackImagePath!,
                        () => _showImagePreviewDialog(
                          _idBackImagePath!,
                          'ID Back Photo',
                        ),
                      ),
                    ],
                  ],
                ),
                if (_fullNameController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Details Auto-Filled from ID Card',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        _buildModuleHeader(
          'Identity Profile',
          'Personal data from your government ID',
        ),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Legal Name'),
              const SizedBox(height: 8),
              _buildTextField(
                _fullNameController,
                'e.g. Juan Dela Cruz',
                prefixIcon: Icons.badge_rounded,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Sex / Gender'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _sexController,
                          'Male / Female',
                          prefixIcon: Icons.wc_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Birth Date'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickBirthDate,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              _birthDateController,
                              'MM/DD/YYYY',
                              prefixIcon: Icons.calendar_today_rounded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildLabel('Place of Birth'),
              const SizedBox(height: 8),
              _buildTextField(
                _placeOfBirthController,
                'City/Municipality, Province',
                prefixIcon: Icons.location_city_rounded,
              ),
              const SizedBox(height: 18),
              _buildLabel(
                _idType == 'local_id' ? 'Local ID Number' : 'ID / PCN Number',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                _pcnController,
                _idType == 'local_id'
                    ? 'e.g., 2729-20'
                    : '16-digit PCN or ID Number',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: _idType == 'local_id'
                    ? TextInputType.text
                    : TextInputType.number,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Module 2: Residential Address
        _buildModuleHeader('Residential Address', 'Where you currently reside'),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Home Address'),
              const SizedBox(height: 8),
              _buildTextField(
                _addressController,
                'Street, Barangay, City, Province',
                maxLines: 2,
                prefixIcon: Icons.home_rounded,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: _primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your address is protected and used only for verification.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Module 3: Farm Portfolio
        _buildModuleHeader(
          'Farm Information',
          'Details about your agricultural land & business',
        ),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Farm Name'),
              const SizedBox(height: 8),
              _buildTextField(
                _farmNameController,
                'e.g. San Carlos Organic Harvest Farm',
                prefixIcon: Icons.agriculture_rounded,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Experience'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _yearsController,
                          'Years (e.g. 5+)',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.history_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Specialty'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          _specialtyController,
                          'e.g. Organic Vegetables',
                          prefixIcon: Icons.eco_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildLabel('Farm GPS Location (Required)'),
              const SizedBox(height: 10),
              InkWell(
                onTap: _openFarmPinPicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _farmLatitude != null
                        ? const Color(0xFFF0FDF4)
                        : _surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _farmLatitude != null ? _primary : _border,
                      width: _farmLatitude != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _farmLatitude != null
                              ? _primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _farmLatitude != null ? _primary : _border,
                          ),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: _farmLatitude != null
                              ? Colors.white
                              : _primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _farmLatitude != null
                                  ? 'GPS Location Pinned'
                                  : 'Tap to Pin Farm on Map',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _resolvedFarmLocation.isNotEmpty
                                  ? _resolvedFarmLocation
                                  : (_farmLatitude != null
                                        ? '${_farmLatitude!.toStringAsFixed(4)}, ${_farmLongitude!.toStringAsFixed(4)}'
                                        : 'Set exact coordinates for buyer transparency'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          _farmLatitude != null ? 'Edit Pin' : 'Open Map',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Module 4: Crops & Livestock Focus
        _buildModuleHeader(
          'Agricultural Products',
          'Select all commodities you produce',
        ),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('Primary Crops'),
                  Text(
                    '${_selectedCrops.length} selected',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCropChip('Rice', '🌾'),
                  _buildCropChip('Corn', '🌽'),
                  _buildCropChip('Vegetables', '🥬'),
                  _buildCropChip('Fruits', '🥭'),
                  _buildCropChip('Root Crops', '🥔'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('Livestock & Poultry'),
                  Text(
                    '${_selectedLivestock.length} selected',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLivestockChip('Carabao', '🐃'),
                  _buildLivestockChip('Cattle', '🐂'),
                  _buildLivestockChip('Swine', '🐖'),
                  _buildLivestockChip('Goat', '🐐'),
                  _buildLivestockChip('Chicken', '🐓'),
                ],
              ),
              const SizedBox(height: 20),
              _buildLabel('Other Livestock'),
              const SizedBox(height: 8),
              _buildTextField(
                _livestockController,
                'Specify others (optional)...',
                prefixIcon: Icons.pets_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildModuleHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary, size: 20),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildScannedThumb(String label, String path, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  height: 60,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in_rounded, size: 11, color: _primary),
                  const SizedBox(width: 2),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreviewDialog(String imagePath, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _dark,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivestockChip(String label, String emoji) {
    final isSelected = _selectedLivestock.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLivestock.remove(label);
          } else {
            _selectedLivestock.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _border.withValues(alpha: 0.5),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropChip(String label, String emoji) {
    final selected = _selectedCrops.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedCrops.remove(label);
          } else {
            _selectedCrops.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _primary : _border.withValues(alpha: 0.5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2: Identity Verification
  // ═══════════════════════════════════════════
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ─── Security & Encryption Assurance Chip ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF16A34A),
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Philippine Agri-KYC: 256-bit encrypted official partner verification.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─── ID Type Selector ───
        _buildSectionTitle('Select Government ID', Icons.badge_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildIdTypeChip(
              'national_id',
              'National ID (PhilSys)',
              Icons.credit_card_rounded,
            ),
            const SizedBox(width: 8),
            _buildIdTypeChip('other_id', 'Other Gov ID', Icons.badge_rounded),
            const SizedBox(width: 8),
            _buildIdTypeChip(
              'local_id',
              'Local / Barangay ID',
              Icons.location_city_rounded,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ─── Module 1: Facial Biometrics Scan ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              '1. Facial Biometrics',
              Icons.face_unlock_rounded,
            ),
            if (_faceScanned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Captured',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _faceScanned ? _primary : _border,
              width: _faceScanned ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (_faceScanned ? _primary : Colors.black).withValues(
                  alpha: 0.04,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _handleFaceScan,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _faceScanned ? Colors.transparent : _surface,
                    border: Border.all(
                      color: _faceScanned
                          ? _primary
                          : _primary.withValues(alpha: 0.3),
                      width: _faceScanned ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_faceScanned ? _primary : _muted).withValues(
                          alpha: 0.1,
                        ),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _faceScanned && _faceImagePath != null
                      ? ClipOval(
                          child: Image.file(
                            File(_faceImagePath!),
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural_rounded,
                              size: 48,
                              color: _primary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to Scan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _faceScanned ? 'Selfie Verified' : 'Real-Time Face Match',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _faceScanned
                    ? 'Your selfie is ready to match against your ID.'
                    : 'Ensure good lighting and remove hats or glasses.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 16),
              if (_faceScanned)
                OutlinedButton.icon(
                  onPressed: _handleFaceScan,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retake Selfie'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _handleFaceScan,
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Take Selfie Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_idType != 'local_id') ...[
          const SizedBox(height: 32),

          // ─── Module 2: Government ID Documents (Front & Back) ───
          _buildSectionTitle(
            '2. ID Card Photos',
            Icons.document_scanner_rounded,
          ),
          const SizedBox(height: 4),
          Text(
            'Capture both front and back sides clearly without glare.',
            style: GoogleFonts.inter(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 14),

          // ID FRONT CARD
          _buildDocumentCaptureCard(
            title: 'ID Front Side',
            subtitle: 'Photo, full legal name, and birth date must be legible.',
            icon: Icons.credit_card_rounded,
            isUploaded: _idUploaded,
            imagePath: _idImagePath,
            onCamera: () => _handleIdUpload('camera', isFront: true),
            onGallery: () => _handleIdUpload('gallery', isFront: true),
            onReplace: () => setState(() {
              _idUploaded = false;
              _idImagePath = null;
            }),
          ),

          const SizedBox(height: 18),

          // ID BACK CARD
          _buildDocumentCaptureCard(
            title: 'ID Back Side',
            subtitle: 'Barcode, card serial numbers, and signatures must be sharp.',
            icon: Icons.flip_to_back_rounded,
            isUploaded: _idBackUploaded,
            imagePath: _idBackImagePath,
            onCamera: () => _handleIdUpload('camera', isFront: false),
            onGallery: () => _handleIdUpload('gallery', isFront: false),
            onReplace: () => setState(() {
              _idBackUploaded = false;
              _idBackImagePath = null;
            }),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildIdTypeChip(String type, String label, IconData icon) {
    final isSelected = _idType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _primary : _border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : _muted),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : _dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCaptureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isUploaded,
    required String? imagePath,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required VoidCallback onReplace,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUploaded ? _primary : _border,
          width: isUploaded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUploaded ? _primary : Colors.black).withValues(
              alpha: 0.03,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isUploaded && imagePath != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: onReplace,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Replace',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(imagePath),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: _primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _dark,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onCamera,
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                        ),
                        label: const Text('Take Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 3: Final Submission & Review
  // ═══════════════════════════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Module 1: Academic & Agricultural Experience
        _buildModuleHeader(
          'Academic & Experience',
          'Tell us about your educational background & farming history',
        ),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Elementary Education'),
              const SizedBox(height: 8),
              _buildTextField(
                _elementaryController,
                'School Name / Year Completed',
                prefixIcon: Icons.school_outlined,
              ),
              const SizedBox(height: 18),
              _buildLabel('Secondary / High School'),
              const SizedBox(height: 8),
              _buildTextField(
                _highSchoolController,
                'School Name / Year Completed',
                prefixIcon: Icons.menu_book_rounded,
              ),
              const SizedBox(height: 18),
              _buildLabel('Tertiary / College / Vocational'),
              const SizedBox(height: 8),
              _buildTextField(
                _collegeController,
                'Degree or Course / University (optional)',
                prefixIcon: Icons.workspace_premium_rounded,
              ),
              const SizedBox(height: 18),
              _buildLabel('Farming Journey & Bio'),
              const SizedBox(height: 8),
              _buildTextField(
                _farmingHistoryController,
                'Describe your farming background, methods, and goals...',
                maxLines: 3,
                prefixIcon: Icons.history_edu_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Module 2: Pre-Submission Verification Summary Card
        _buildModuleHeader(
          'Review Application',
          'Confirm your details before final submission',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary.withValues(alpha: 0.08), Colors.white],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _primary.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Application Summary',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready to Submit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryRow(
                'Farmer Name',
                _fullNameController.text.isNotEmpty
                    ? _fullNameController.text
                    : 'Not provided',
                Icons.person_rounded,
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                'Farm Name',
                _farmNameController.text.isNotEmpty
                    ? _farmNameController.text
                    : 'Not provided',
                Icons.agriculture_rounded,
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                'Farm Location',
                _farmLatitude != null
                    ? 'GPS Pinned (${_farmLatitude!.toStringAsFixed(3)}, ${_farmLongitude!.toStringAsFixed(3)})'
                    : 'Not pinned',
                Icons.location_on_rounded,
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                'Identity Docs',
                _faceScanned && _idUploaded && _idBackUploaded
                    ? 'Selfie & Both ID sides uploaded'
                    : 'Documents attached',
                Icons.badge_rounded,
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                'Crops / Livestock',
                '${_selectedCrops.length} crops, ${_selectedLivestock.length} livestock types',
                Icons.eco_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Module 3: Legal Certification
        _buildCertificationCheckbox(),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12.5, color: _muted),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificationCheckbox() {
    return GestureDetector(
      onTap: () =>
          setState(() => _certificationAccepted = !_certificationAccepted),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _certificationAccepted
              ? _primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _certificationAccepted ? _primary : _border,
            width: _certificationAccepted ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (_certificationAccepted ? _primary : Colors.black)
                  .withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _certificationAccepted ? _primary : Colors.white,
                border: Border.all(
                  color: _certificationAccepted ? _primary : _border,
                  width: 2,
                ),
              ),
              child: _certificationAccepted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Declaration & Certification',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'I certify that all information and documents provided are true and accurate. I understand that falsification will result in registration revocation.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: _muted,
                      height: 1.4,
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

  // ─── Bottom Button ───
  Widget _buildBottomButton() {
    final isLastStep = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: GestureDetector(
          onTap: _isSubmitting
              ? null
              : (isLastStep ? _handleSubmit : _handleNext),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLastStep
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF10B981), _accent],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: AppShimmerLoader(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLastStep ? 'Submit for Approval' : 'Next Step',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLastStep ? Icons.send_rounded : Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _dark.withValues(alpha: 0.8),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    IconData? suffixIcon,
    IconData? prefixIcon,
    bool readOnly = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: readOnly ? _surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: readOnly ? _border.withValues(alpha: 0.5) : _border,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: _dark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: _muted.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, size: 20, color: _muted.withValues(alpha: 0.5))
              : null,
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  size: 20,
                  color: _primary.withValues(alpha: 0.5),
                )
              : null,
        ),
      ),
    );
  }

  // ─── Actions ───
  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _dark,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      // Store in RPC friendly format YYYY-MM-DD behind the scenes
      // But display as MM/DD/YYYY for user comfort
      setState(() {
        _birthDateController.text =
            '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
        // We can use the controller text for display and a hidden value for DB
        _registration.birthDate =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _handleFaceScan() async {
    final path = await context.push<String>(AppRoutes.faceCapture);
    if (path != null && mounted) {
      setState(() {
        _faceScanned = true;
        _faceImagePath = path;
      });

      // Capture bytes if on Web or for immediate upload
      if (kIsWeb || path.startsWith('blob:')) {
        final bytes = await XFile(path).readAsBytes();
        setState(() => _faceImageBytes = bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Face captured successfully!'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleIdUpload(String source, {bool isFront = true}) async {
    try {
      String? imagePath;
      String? qrPayload;

      if (source == 'camera') {
        if (!isFront && _idType == 'national_id') {
          // Automatic stream scanner for PhilSys National ID Back
          final result = await Navigator.of(context).push<IdBackCaptureResult>(
            MaterialPageRoute(
              builder: (context) =>
                  const IdBackCaptureScreen(label: 'PhilSys QR Auto-Scan'),
            ),
          );
          if (result != null) {
            imagePath = result.imagePath;
            qrPayload = result.qrData;
          }
        } else {
          // Front or other ID photo capture
          imagePath = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (context) =>
                  IdCaptureScreen(label: isFront ? 'ID Front' : 'ID Back'),
            ),
          );
        }
      } else {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        imagePath = image?.path;

        // If National ID Back is uploaded from gallery, extract QR
        if (imagePath != null && !isFront && _idType == 'national_id') {
          try {
            final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
            final barcodes = await barcodeScanner.processImage(
              InputImage.fromFilePath(imagePath),
            );
            await barcodeScanner.close();
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              qrPayload = barcodes.first.rawValue;
            }
          } catch (e) {
            debugPrint('Gallery QR scan error: $e');
          }
        }
      }

      if (imagePath != null && mounted) {
        final file = File(imagePath);
        final bytes = await file.readAsBytes();
        setState(() {
          if (isFront) {
            _idUploaded = true;
            _idImagePath = imagePath;
            _idImageBytes = bytes;
          } else {
            _idBackUploaded = true;
            _idBackImagePath = imagePath;
          }
        });

        // ── 1. If ID Front: Run OCR text recognition to extract Name, DOB, Sex, PCN ──
        if (isFront) {
          _processIdFrontOcr(imagePath);
        }

        // ── 2. If ID Back: Process QR Code payload ──
        if (qrPayload != null && qrPayload.isNotEmpty) {
          _processQrData(qrPayload);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isFront ? "Front" : "Back"} ID captured successfully!',
            ),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to capture ID: $e');
      }
    }
  }

  Future<void> _processIdFrontOcr(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final fullText = recognizedText.text;
      debugPrint('[OCR ID Front] Extracted Text:\n$fullText');

      String? foundLastName;
      String? foundFirstName;
      String? foundMiddleName;
      String? foundSex;
      String? foundDob;
      String? foundPcn;

      // 1. Check 16-digit PCN format (e.g. 1234-5678-9012-3456)
      final pcnRegex = RegExp(r'\b\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{4}\b');
      final pcnMatch = pcnRegex.firstMatch(fullText);
      if (pcnMatch != null) {
        foundPcn = pcnMatch.group(0)?.replaceAll(' ', '-');
      }

      // 2. Check Sex / Gender
      if (RegExp(r'\b(MALE|LALAKI)\b', caseSensitive: false).hasMatch(fullText)) {
        foundSex = 'Male';
      } else if (RegExp(r'\b(FEMALE|BABAE)\b', caseSensitive: false).hasMatch(fullText)) {
        foundSex = 'Female';
      }

      // 3. Check Date of Birth (e.g. August 15, 2003 or 15/08/2003 or 2003-08-15)
      final dobRegex = RegExp(
        r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b|\b\d{2}/\d{2}/\d{4}\b|\b\d{4}-\d{2}-\d{2}\b',
        caseSensitive: false,
      );
      final dobMatch = dobRegex.firstMatch(fullText);
      if (dobMatch != null) {
        foundDob = dobMatch.group(0);
      }

      // 4. Parse block lines for Philippine ID name fields
      final lines = recognizedText.blocks
          .expand((b) => b.lines)
          .map((l) => l.text.trim())
          .toList();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toUpperCase();

        if ((line.contains('LAST NAME') || line.contains('APELYIDO')) && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!nextLine.contains('/') && !nextLine.toUpperCase().contains('NAME') && nextLine.length >= 2) {
            foundLastName = nextLine;
          }
        } else if ((line.contains('GIVEN') || line.contains('PANGALAN') || line.contains('FIRST NAME')) && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!nextLine.contains('/') && !nextLine.toUpperCase().contains('NAME') && nextLine.length >= 2) {
            foundFirstName = nextLine;
          }
        } else if ((line.contains('MIDDLE') || line.contains('GITNANG')) && i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!nextLine.contains('/') && !nextLine.toUpperCase().contains('NAME') && nextLine.length >= 2) {
            foundMiddleName = nextLine;
          }
        }
      }

      final nameParts = [foundFirstName, foundMiddleName, foundLastName]
          .where((s) => s != null && s.isNotEmpty)
          .toList();

      bool didFillAny = false;

      if (nameParts.isNotEmpty && _fullNameController.text.trim().isEmpty) {
        _fullNameController.text = nameParts.join(' ');
        didFillAny = true;
      }
      if (foundSex != null && _sexController.text.trim().isEmpty) {
        _sexController.text = foundSex;
        didFillAny = true;
      }
      if (foundDob != null && _birthDateController.text.trim().isEmpty) {
        _birthDateController.text = foundDob;
        _registration.birthDate = foundDob;
        didFillAny = true;
      }
      if (foundPcn != null && _pcnController.text.trim().isEmpty) {
        _pcnController.text = foundPcn;
        didFillAny = true;
      }

      if (didFillAny && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('ID Front recognized! Profile data auto-filled.'),
                ),
              ],
            ),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[OCR ID Front Error] $e');
    }
  }

  void _processQrData(String qrRaw) {
    try {
      debugPrint('[QR Raw Data] $qrRaw');
      Map<String, dynamic> subject = {};

      String cleanQr = qrRaw.trim();

      // Case 1: Direct JSON
      if (cleanQr.startsWith('{') && cleanQr.endsWith('}')) {
        final data = jsonDecode(cleanQr);
        if (data is Map<String, dynamic>) {
          subject = data.containsKey('subject') && data['subject'] is Map<String, dynamic>
              ? (data['subject'] as Map<String, dynamic>)
              : data;
        }
      }
      // Case 2: JWT (header.payload.signature)
      else if (cleanQr.contains('.')) {
        final parts = cleanQr.split('.');
        if (parts.length >= 2) {
          try {
            String payloadBase64 = parts[1];
            while (payloadBase64.length % 4 != 0) {
              payloadBase64 += '=';
            }
            final decodedBytes = base64Url.decode(payloadBase64);
            final decodedStr = utf8.decode(decodedBytes);
            final data = jsonDecode(decodedStr);
            if (data is Map<String, dynamic>) {
              subject = data.containsKey('subject') && data['subject'] is Map<String, dynamic>
                  ? (data['subject'] as Map<String, dynamic>)
                  : data;
            }
          } catch (e) {
            debugPrint('JWT decode error: $e');
          }
        }
      }

      // Name resolution (fName, mName, lName, Suffix)
      final fName = subject['fName'] ?? subject['firstName'] ?? subject['First_Name'] ?? '';
      final mName = subject['mName'] ?? subject['middleName'] ?? subject['Middle_Name'] ?? '';
      final lName = subject['lName'] ?? subject['lastName'] ?? subject['Last_Name'] ?? '';
      final suffix = subject['Suffix'] ?? subject['suffix'] ?? '';

      final constructedName = [fName, mName, lName, suffix]
          .where((e) => e.toString().trim().isNotEmpty)
          .join(' ');

      if (constructedName.isNotEmpty) {
        _fullNameController.text = constructedName;
      }

      // Sex / Gender
      final sex = subject['sex'] ?? subject['Sex'] ?? subject['Gender'] ?? subject['gender'] ?? '';
      if (sex.toString().isNotEmpty) {
        _sexController.text = sex.toString();
      }

      // Place of Birth
      final pob = subject['POB'] ?? subject['pob'] ?? subject['BirthPlace'] ?? subject['placeOfBirth'] ?? '';
      if (pob.toString().isNotEmpty) {
        _placeOfBirthController.text = pob.toString();
      }

      // PCN (PhilSys Card Number)
      final pcn = subject['PCN'] ?? subject['pcn'] ?? subject['CardNumber'] ?? subject['idNumber'] ?? '';
      if (pcn.toString().isNotEmpty) {
        _pcnController.text = pcn.toString();
      }

      // Birth Date
      final dob = subject['DOB'] ?? subject['dob'] ?? subject['BirthDate'] ?? subject['birthDate'] ?? '';
      if (dob.toString().isNotEmpty) {
        final dobStr = dob.toString();
        if (dobStr.contains('-')) {
          final parts = dobStr.split('-');
          if (parts.length == 3) {
            _birthDateController.text = '${parts[1]}/${parts[2]}/${parts[0]}';
            _registration.birthDate = dobStr;
          } else {
            _birthDateController.text = dobStr;
          }
        } else {
          _birthDateController.text = dobStr;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('ID recognized! Profile data auto-filled.'),
                ),
              ],
            ),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error parsing PhilSys QR data: $e');
    }
  }

  void _showVerificationGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VerificationGuideWidget(),
    );
  }

  void _handleNext() {
    // Validate current step
    if (_currentStep == 0) {
      if (!_faceScanned) {
        _showError('Please complete your selfie face scan');
        return;
      }
      if (_idType != 'local_id') {
        if (!_idUploaded) {
          _showError('Please capture the front of your ID card');
          return;
        }
        if (!_idBackUploaded) {
          _showError('Please capture the back of your ID card');
          return;
        }
      }
    } else if (_currentStep == 1) {
      if (_fullNameController.text.trim().isEmpty) {
        _showError('Please enter your full name');
        return;
      }
      if (_sexController.text.trim().isEmpty) {
        _showError('Please enter your sex/gender');
        return;
      }
      if (_placeOfBirthController.text.trim().isEmpty) {
        _showError('Please enter your place of birth');
        return;
      }
      if (_idType == 'national_id' && _pcnController.text.trim().isEmpty) {
        _showError('Please enter your National ID / PCN number');
        return;
      }
      if (_idType == 'local_id' && _pcnController.text.trim().isEmpty) {
        _showError('Please enter your Local ID number');
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        _showError('Please enter your residential address');
        return;
      }
      if (_farmNameController.text.trim().isEmpty) {
        _showError('Please enter your farm name');
        return;
      }
      if (_farmLatitude == null || _farmLongitude == null) {
        _showError('Please pin your farm location on the map');
        return;
      }
    }

    setState(() => _currentStep++);
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_certificationAccepted) {
      _showError('Please accept the certification to proceed');
      return;
    }

    setState(() => _isSubmitting = true);

    // Populate the registration model
    _registration.idType = _idType;
    _registration.fullName = _fullNameController.text.trim();
    _registration.sex = _sexController.text.trim();
    _registration.placeOfBirth = _placeOfBirthController.text.trim();

    // PCN is now auto-populated into the controller after QR scan
    _registration.pcn = _pcnController.text.trim();

    _registration.birthDate = _birthDateController.text.trim();
    _registration.residentialAddress = _addressController.text.trim();
    _registration.validIdPath = _idImagePath;
    _registration.validIdBackPath = _idBackImagePath;
    _registration.facePhotoPath = _faceImagePath;
    _registration.farmLatitude = _farmLatitude;
    _registration.farmLongitude = _farmLongitude;
    _registration.farmName = _farmNameController.text.trim();
    _registration.specialty = _specialtyController.text.trim();
    _registration.cropTypes = _selectedCrops.toList();

    List<String> combinedLivestock = _selectedLivestock.toList();
    if (_livestockController.text.trim().isNotEmpty) {
      combinedLivestock.add(_livestockController.text.trim());
    }
    _registration.livestock = combinedLivestock.join(', ');
    _registration.facePhotoPath = _faceImagePath;
    _registration.validIdPath = _idImagePath;
    _registration.elementary = _elementaryController.text.trim();
    _registration.highSchool = _highSchoolController.text.trim();
    _registration.college = _collegeController.text.trim();
    _registration.farmingHistory = _farmingHistoryController.text.trim();
    _registration.yearsOfExperience = _yearsController.text.trim();
    _registration.certificationAccepted = _certificationAccepted;

    try {
      final auth = AuthService();

      // Submit registration to Supabase
      await SupabaseDatabase.submitFarmerRegistration(
        userId: auth.userId,
        registration: _registration,
        faceImageBytes: _faceImageBytes,
        idImageBytes: _idImageBytes,
        resolvedFarmLocation: _resolvedFarmLocation,
      );

      // Refresh registration status in AuthService so profile UI updates immediately
      await auth.refreshRegistrationStatus();

      // DON'T activate seller mode yet - wait for admin approval
      // await auth.startSelling();

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, size: 56, color: _primary),
                ),
                const SizedBox(height: 20),
                Text(
                  'Registration Submitted!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your farmer registration has been submitted for admin review. You will be notified once approved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      if (_isClosingSuccessDialog) return;
                      _isClosingSuccessDialog = true;

                      if (Navigator.of(ctx).canPop()) {
                        Navigator.of(ctx).pop();
                      }

                      if (!mounted) return;

                      final rootNavigator = Navigator.of(context);
                      if (rootNavigator.canPop()) {
                        rootNavigator.pop();
                      }
                      widget.onRegistrationComplete();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_primary, _accent]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          'Go to Dashboard',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
    } catch (e) {
      if (mounted) {
        _showError('Registration failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  LatLng _defaultPin() {
    if (_farmLatitude != null && _farmLongitude != null) {
      return LatLng(_farmLatitude!, _farmLongitude!);
    }
    return const LatLng(10.3157, 123.8854);
  }

  Future<void> _openFarmPinPicker() async {
    final mapController = MapController();
    var selectedPin = _defaultPin();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isLocating = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: SizedBox(
                width: 700,
                height: 600,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pin Farm Location',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _dark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Tag your farm accurately on the map',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: _muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _surface,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
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
                                    retinaMode: RetinaMode.isHighDensity(
                                      context,
                                    ),
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        width: 48,
                                        height: 48,
                                        point: selectedPin,
                                        alignment: Alignment.bottomCenter,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.redAccent,
                                          size: 44,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Locate Me Button
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton.small(
                                onPressed: isLocating
                                    ? null
                                    : () async {
                                        setModalState(() => isLocating = true);
                                        try {
                                          LocationPermission permission =
                                              await Geolocator.checkPermission();
                                          if (permission ==
                                              LocationPermission.denied) {
                                            permission =
                                                await Geolocator.requestPermission();
                                          }

                                          if (permission ==
                                                  LocationPermission
                                                      .whileInUse ||
                                              permission ==
                                                  LocationPermission.always) {
                                            final pos =
                                                await Geolocator.getCurrentPosition();
                                            final point = LatLng(
                                              pos.latitude,
                                              pos.longitude,
                                            );
                                            setModalState(() {
                                              selectedPin = point;
                                              isLocating = false;
                                            });
                                            mapController.move(point, 18);
                                          } else {
                                            setModalState(
                                              () => isLocating = false,
                                            );
                                            if (mounted) {
                                              _showError(
                                                'Location permission denied',
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          setModalState(
                                            () => isLocating = false,
                                          );
                                          if (mounted) {
                                            _showError(
                                              'Failed to get location: $e',
                                            );
                                          }
                                        }
                                      },
                                backgroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: isLocating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _primary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        color: _primary,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 16,
                                  color: _primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Coordinates: ${selectedPin.latitude.toStringAsFixed(6)}, ${selectedPin.longitude.toStringAsFixed(6)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: _dark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final resolved =
                                        await ReverseGeocodingService.resolveFromCoordinates(
                                          latitude: selectedPin.latitude,
                                          longitude: selectedPin.longitude,
                                        );

                                    final fallbackLocation =
                                        '${selectedPin.latitude.toStringAsFixed(5)}, ${selectedPin.longitude.toStringAsFixed(5)}';

                                    if (!mounted) return;
                                    setState(() {
                                      _farmLatitude = selectedPin.latitude;
                                      _farmLongitude = selectedPin.longitude;
                                      _resolvedFarmLocation = resolved.hasData
                                          ? resolved.fullAddress
                                          : fallbackLocation;
                                    });
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Set Farm Location',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
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
            );
          },
        );
      },
    );
  }
}
