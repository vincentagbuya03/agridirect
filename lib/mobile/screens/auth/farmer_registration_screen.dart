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
import '../../../shared/router/app_router.dart';
import 'dart:convert';
import '../../widgets/auth/verification_guide_widget.dart';
import '../common/id_capture_screen.dart';
import '../common/id_back_capture_screen.dart';
import 'package:geolocator/geolocator.dart';

/// Mobile Farmer Registration — 3-step wizard.
/// Step 1: Personal Data & Farm Details
/// Step 2: Identity Verification (Face Scan + Valid ID)
/// Step 3: Final Submission (Education, Work, Signature)
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

  // New Personal Data Controllers (pre-filled by QR)
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
  bool _idBackUploaded = false; // ID Back / QR Scanned
  String? _idBackImagePath;
  Map<String, dynamic>? _qrData;
  final ImagePicker _imagePicker = ImagePicker();

  // Signature
  final List<Offset?> _signaturePoints = [];
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
                _buildAppBar(),
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

  // ─── App Bar ───
  Widget _buildAppBar() {
    final titles = [
      'Identity Verification',
      'Farm & Personal Data',
      'Final Submission',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _dark,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titles[_currentStep],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Become a verified AgriDirect partner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildProgressCircle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: AppShimmerLoader(
            value: (_currentStep + 1) / 3,
            backgroundColor: _border,
            color: _primary,
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          '${_currentStep + 1}/3',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }

  // ─── Step Indicator ───
  Widget _buildStepIndicator() {
    final labels = ['Verification', 'Profiles', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(3, (i) {
          final isCompleted = i < _currentStep;
          final isCurrent = i == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        decoration: BoxDecoration(
                          color: isCurrent || isCompleted ? _primary : _border,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isCurrent ? _dark : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
            ),
          );
        }),
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
        const SizedBox(height: 12),
        // Personal Information Module
        _buildModuleHeader('Identity Profile', 'Personal verification data'),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Legal Name'),
              const SizedBox(height: 10),
              _buildTextField(
                _fullNameController,
                'As shown on your ID',
                prefixIcon: Icons.badge_rounded,
                readOnly: _idType == 'national_id' && _qrData != null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Sex'),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _sexController,
                          'Gender',
                          prefixIcon: Icons.wc_rounded,
                          readOnly: _idType == 'national_id' && _qrData != null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Birth Date'),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _idType == 'national_id'
                              ? null
                              : _pickBirthDate,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              _birthDateController,
                              'mm/dd/yyyy',
                              prefixIcon: Icons.calendar_today_rounded,
                              readOnly: _idType == 'national_id',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLabel('Place of Birth'),
              const SizedBox(height: 10),
              _buildTextField(
                _placeOfBirthController,
                'City/Municipality, Province',
                prefixIcon: Icons.location_city_rounded,
                readOnly: _idType == 'national_id' && _qrData != null,
              ),
              const SizedBox(height: 20),
              _buildLabel('PCN (PhilSys Card Number)'),
              const SizedBox(height: 10),
              _buildTextField(
                _pcnController,
                '16-digit number (if applicable)',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Residence Module
        _buildModuleHeader('Residential Address', 'Where you currently live'),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Home Address'),
              const SizedBox(height: 10),
              _buildTextField(
                _addressController,
                'Street, Barangay, City, Province',
                maxLines: 2,
                prefixIcon: Icons.home_rounded,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This address will be used for official communications.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Farm Portfolio Module
        _buildModuleHeader(
          'Farm Information',
          'Details about your agricultural business',
        ),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Farm Name'),
              const SizedBox(height: 10),
              _buildTextField(
                _farmNameController,
                'e.g. Green Valley Farm',
                prefixIcon: Icons.agriculture_rounded,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Experience'),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _yearsController,
                          'Years',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.history_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Specialty'),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _specialtyController,
                          'Organic/High-Yield',
                          prefixIcon: Icons.auto_awesome_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('Farm Location'),
              const SizedBox(height: 12),
              InkWell(
                onTap: _openFarmPinPicker,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primary.withValues(alpha: 0.1),
                        _accent.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _farmLatitude != null
                              ? Icons.location_on_rounded
                              : Icons.map_rounded,
                          color: _primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _farmLatitude != null
                                  ? 'Location Captured'
                                  : 'Select Farm Location',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            Text(
                              _resolvedFarmLocation.isNotEmpty
                                  ? _resolvedFarmLocation
                                  : 'Tap to pin your farm on the map',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _muted,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Crop & Livestock Module
        _buildModuleHeader('Product Focus', 'What do you produce?'),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Primary Crops'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildCropChip('Rice', '🌾'),
                  _buildCropChip('Corn', '🌽'),
                  _buildCropChip('Vegetables', '🌶️'),
                  _buildCropChip('Fruits', '🍎'),
                  _buildCropChip('Root Crops', '🥔'),
                ],
              ),
              const SizedBox(height: 28),
              _buildLabel('Livestock Inventory'),
              const SizedBox(height: 16),
              _buildCategoryTitle('ANIMALS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildLivestockChip('Carabao', '🐃'),
                  _buildLivestockChip('Cattle', '🐂'),
                  _buildLivestockChip('Swine', '🐖'),
                  _buildLivestockChip('Goat', '🐐'),
                  _buildLivestockChip('Chicken', '🐓'),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('Other Livestock'),
              const SizedBox(height: 10),
              _buildTextField(
                _livestockController,
                'Specify others...',
                prefixIcon: Icons.pets_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
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

  Widget _buildCategoryTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _muted,
        letterSpacing: 1.2,
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
        const SizedBox(height: 12),
        _buildSectionTitle('Verification Guide', Icons.info_outline_rounded),
        const SizedBox(height: 12),
        Text(
          'Please follow these steps:\n1. Select your ID Type.\n2. Complete the Face Scan.\n3. Scan the Front of your ID.\n4. Scan the Back of your ID (For National ID, scan the QR code to auto-fill your details).',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: _muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Select ID Type', Icons.badge_rounded),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _idType = 'national_id'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _idType == 'national_id' ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _idType == 'national_id' ? _primary : _border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'National ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: _idType == 'national_id' ? Colors.white : _dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _idType = 'local_id'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _idType == 'local_id' ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _idType == 'local_id' ? _primary : _border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Local ID (San Carlos)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: _idType == 'local_id' ? Colors.white : _dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: _buildSectionTitle(
                'Biometric Scan',
                Icons.face_unlock_rounded,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _showVerificationGuide,
              icon: const Icon(Icons.info_outline_rounded, size: 16),
              label: Text(
                'How to verify?',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Face circle
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _handleFaceScan,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: _faceScanned ? _primary : _border,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_faceScanned ? _primary : _muted).withValues(
                          alpha: 0.1,
                        ),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _faceScanned && _faceImagePath != null
                      ? ClipOval(
                          child: Image.file(
                            File(_faceImagePath!),
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 72,
                              color: _primary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to Scan Face',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: _muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_faceScanned)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _faceScanned = false;
                      _faceImagePath = null;
                    }),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Retake Face Photo',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(foregroundColor: _primary),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 40),
        _buildSectionTitle('ID Front Scan', Icons.badge_rounded),
        const SizedBox(height: 16),

        // Upload box Front
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _idUploaded
              ? Column(
                  children: [
                    if (_idImagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_idImagePath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Front ID Captured',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _idUploaded = false;
                        _idImagePath = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'REPLACE FRONT',
                        style: GoogleFonts.plusJakartaSans(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_front_rounded,
                        size: 32,
                        color: _primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scan ID Front',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildUploadOption(
                      Icons.camera_alt_rounded,
                      'Open Camera',
                      onTap: () => _handleIdUpload('camera', isFront: true),
                      isActive: true,
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 40),
        _buildSectionTitle(
          _idType == 'national_id' ? 'ID Back QR Scan' : 'ID Back Scan',
          Icons.qr_code_scanner_rounded,
        ),
        const SizedBox(height: 16),

        // Upload box Back/QR
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _idBackUploaded
              ? Column(
                  children: [
                    if (_idBackImagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_idBackImagePath!),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (_qrData != null)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _primary,
                        size: 64,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _idType == 'national_id'
                          ? 'QR Data Extracted'
                          : 'Back ID Captured',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    if (_qrData != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Data has been autofilled in the next step.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _idBackUploaded = false;
                        _idBackImagePath = null;
                        _qrData = null;
                      }),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _idType == 'national_id' ? 'RESCAN QR' : 'REPLACE BACK',
                        style: GoogleFonts.plusJakartaSans(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _idType == 'national_id'
                            ? Icons.qr_code_scanner_rounded
                            : Icons.camera_rear_rounded,
                        size: 32,
                        color: _primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _idType == 'national_id'
                          ? 'Scan PhilSys QR Code'
                          : 'Scan ID Back',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildUploadOption(
                      Icons.camera_alt_rounded,
                      'Open Camera',
                      onTap: _idType == 'national_id'
                          ? _openQRScanner
                          : () => _handleIdUpload('camera', isFront: false),
                      isActive: true,
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildUploadOption(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? _primary : _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : _dark),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 3: Final Submission
  // ═══════════════════════════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildSectionTitle('Academic Background', Icons.school_rounded),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallLabel('ELEMENTARY EDUCATION'),
              _buildUnderlineField(_elementaryController, 'School Name / Year'),
              const SizedBox(height: 20),
              _buildSmallLabel('SECONDARY EDUCATION'),
              _buildUnderlineField(_highSchoolController, 'School Name / Year'),
              const SizedBox(height: 20),
              _buildSmallLabel('TERTIARY EDUCATION'),
              _buildUnderlineField(_collegeController, 'Degree / University'),
            ],
          ),
        ),

        const SizedBox(height: 32),
        _buildSectionTitle('Farming Expertise', Icons.history_edu_rounded),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallLabel('PREVIOUS EXPERIENCE'),
              _buildUnderlineField(
                _farmingHistoryController,
                'Briefly describe your farming journey...',
                maxLines: 3,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        _buildSectionTitle('E-Signature', Icons.draw_rounded),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    if (_signaturePoints.isEmpty)
                      Center(
                        child: Text(
                          'Draw your signature here',
                          style: GoogleFonts.plusJakartaSans(
                            color: _muted.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(
                          () => _signaturePoints.add(details.localPosition),
                        );
                      },
                      onPanEnd: (_) => _signaturePoints.add(null),
                      child: CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _SignaturePainter(_signaturePoints),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _border),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _signaturePoints.clear()),
                      icon: const Icon(
                        Icons.cleaning_services_rounded,
                        size: 16,
                      ),
                      label: Text(
                        'CLEAR',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        _buildCertificationCheckbox(),
        const SizedBox(height: 24),
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
              ? _primary.withValues(alpha: 0.1)
              : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _certificationAccepted ? _primary : _border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _certificationAccepted ? _primary : Colors.white,
                border: Border.all(
                  color: _certificationAccepted ? _primary : _border,
                  width: 2,
                ),
              ),
              child: _certificationAccepted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I certify that all information provided is accurate. I understand that misrepresentation may lead to rejection.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _dark.withValues(alpha: 0.8),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
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

  Widget _buildSmallLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.5,
        ),
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

  Widget _buildUnderlineField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: _muted.withValues(alpha: 0.5),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _primary),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
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

      if (source == 'camera') {
        // Use the new dedicated ID capture screen with guide box
        imagePath = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) =>
                IdCaptureScreen(label: isFront ? 'ID Front' : 'ID Back'),
          ),
        );
      } else {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        imagePath = image?.path;
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

  Future<void> _openQRScanner() async {
    final result = await Navigator.of(context).push<IdBackCaptureResult>(
      MaterialPageRoute(
        builder: (context) =>
            const IdBackCaptureScreen(label: 'ID Back - QR Scan'),
      ),
    );

    if (result != null && mounted) {
      try {
        final data = jsonDecode(result.qrData);
        // PhilSys QR often has data inside a 'subject' key or directly in the root
        final Map<String, dynamic> subject = data.containsKey('subject')
            ? (data['subject'] as Map<String, dynamic>)
            : (data is Map<String, dynamic> ? data : {});

        setState(() {
          _qrData = data;
          _idBackUploaded = true;
          _idBackImagePath = result.imagePath; // CRITICAL: Save the photo path

          // Robust auto-fill mapping with fallback keys
          final fName = subject['fName'] ?? subject['firstName'] ?? '';
          final mName = subject['mName'] ?? subject['middleName'] ?? '';
          final lName = subject['lName'] ?? subject['lastName'] ?? '';
          final suffix = subject['Suffix'] ?? subject['suffix'] ?? '';

          _fullNameController.text = [
            fName,
            mName,
            lName,
            suffix,
          ].where((e) => e.toString().trim().isNotEmpty).join(' ');

          // Fallback mapping for Sex/Gender
          _sexController.text =
              subject['sex'] ?? subject['Gender'] ?? subject['gender'] ?? '';

          _placeOfBirthController.text =
              subject['POB'] ??
              subject['pob'] ??
              subject['BirthPlace'] ??
              subject['placeOfBirth'] ??
              '';

          // Extract and populate PCN automatically
          _pcnController.text =
              (subject['PCN'] ?? subject['pcn'] ?? subject['CardNumber'] ?? '')
                  .toString();

          // Parse DOB with fallback keys
          final dob =
              subject['DOB'] ?? subject['dob'] ?? subject['BirthDate'] ?? '';
          if (dob.toString().isNotEmpty) {
            try {
              _birthDateController.text = dob.toString();
              // If it's in YYYY-MM-DD format, set the registration field directly
              if (dob.toString().contains('-')) {
                _registration.birthDate = dob.toString();
              }
            } catch (_) {}
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ID Back and data captured successfully!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        // Fallback: If JSON parsing fails, at least we have the photo
        setState(() {
          _idBackUploaded = true;
          _idBackImagePath = result.imagePath;
        });
        debugPrint('QR Data Parse Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ID Back photo captured, but QR data could not be parsed.',
              ),
            ),
          );
        }
      }
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
        _showError('Please complete the face scan');
        return;
      }
      if (!_idUploaded) {
        _showError('Please scan the front of your ID');
        return;
      }
      if (!_idBackUploaded) {
        _showError(
          _idType == 'national_id'
              ? 'Please scan the back QR code of your National ID'
              : 'Please scan the back of your ID',
        );
        return;
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
      if (_idType == 'national_id' &&
          _pcnController.text.trim().isEmpty &&
          _qrData == null) {
        _showError('Please enter your PCN for National ID verification');
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
    }

    setState(() => _currentStep++);
  }

  Future<void> _handleSubmit() async {
    if (!_certificationAccepted) {
      _showError('Please accept the certification to proceed');
      return;
    }
    if (_signaturePoints.isEmpty) {
      _showError('Please provide your electronic signature');
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
    _registration.hasSigned = _signaturePoints.isNotEmpty;
    _registration.certificationAccepted = _certificationAccepted;

    try {
      final auth = AuthService();

      // Submit registration to Supabase
      await SupabaseDatabase.submitFarmerRegistration(
        userId: auth.userId,
        registration: _registration,
        faceImageBytes: _faceImageBytes,
        idImageBytes: _idImageBytes,
      );

      if (_resolvedFarmLocation.trim().isNotEmpty) {
        await SupabaseConfig.client
            .from('farmers')
            .update({'location': _resolvedFarmLocation.trim()})
            .eq('user_id', auth.userId);
      }

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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ─── Signature Painter ───
class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
