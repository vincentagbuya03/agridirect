import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/models/farmer_registration.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/supabase_config.dart';
import '../../../shared/router/app_router.dart';

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
  static const Color _primary = Color(0xFF10B981);
  static const Color _accent = Color(0xFF13EC5B);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  int _currentStep = 0;
  bool _isSubmitting = false;
  final _registration = FarmerRegistration();

  // Step 1 controllers
  final _birthDateController = TextEditingController();
  final _yearsController = TextEditingController();
  final _addressController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _livestockController = TextEditingController();
  final Set<String> _selectedCrops = {};

  // Step 3 controllers
  final _elementaryController = TextEditingController();
  final _highSchoolController = TextEditingController();
  final _collegeController = TextEditingController();
  final _farmingHistoryController = TextEditingController();
  bool _certificationAccepted = false;

  // Step 2 state
  bool _faceScanned = false;
  bool _idUploaded = false;
  String? _faceImagePath;
  String? _idImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  // Signature
  final List<Offset?> _signaturePoints = [];

  @override
  void dispose() {
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
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ───
  Widget _buildAppBar() {
    final titles = [
      'Registration',
      'Verification',
      'Final Review',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_left_rounded, color: _dark, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titles[_currentStep],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'STEP ${_currentStep + 1} OF 3',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.help_outline_rounded, size: 20, color: _primary),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ───
  Widget _buildStepIndicator() {
    final labels = ['Info', 'Identity', 'Submit'];
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withOpacity(0.5)),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isCompleted = i < _currentStep;
          final isCurrent = i == _currentStep;
          final isActive = i <= _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            i <= _currentStep ? _primary : _border,
                            (i + 1) <= _currentStep ? _primary : _border,
                          ],
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCurrent ? _primary : (isCompleted ? _primary.withOpacity(0.2) : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? _primary : _border,
                          width: 2,
                        ),
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: _primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ] : null,
                      ),
                      child: Center(
                        child: isCompleted 
                          ? const Icon(Icons.check, size: 14, color: _primary)
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? Colors.white : _muted,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent ? _primary : _muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
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
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
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
        _buildSectionTitle('Personal Identity', Icons.person_rounded),
        const SizedBox(height: 20),
        
        Row(
          children: [
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
                        'mm/dd/yyyy',
                        prefixIcon: Icons.calendar_month_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Years in Farming'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _yearsController,
                    'e.g. 5',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.timer_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        _buildLabel('Residential Address'),
        const SizedBox(height: 8),
        _buildTextField(
          _addressController,
          'Street, Barangay, City, Province',
          maxLines: 2,
          prefixIcon: Icons.location_on_outlined,
        ),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Farm Portfolio', Icons.agriculture_rounded),
        const SizedBox(height: 20),

        _buildLabel('Farm Name'),
        const SizedBox(height: 8),
        _buildTextField(_farmNameController, 'Give your farm a branding name', prefixIcon: Icons.business_outlined),
        const SizedBox(height: 18),

        _buildLabel('Farmer Specialty'),
        const SizedBox(height: 8),
        _buildTextField(_specialtyController, 'e.g. Organic, High-Yield, Hydroponics', prefixIcon: Icons.star_outline_rounded),
        const SizedBox(height: 18),

        _buildLabel('Farming Area (Crop Types)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildCropChip('Rice', '🌾'),
            _buildCropChip('Corn', '🌽'),
            _buildCropChip('Vegetables', '🌶️'),
            _buildCropChip('Fruits', '🍎'),
            _buildCropChip('Root Crops', '🥔'),
          ],
        ),
        const SizedBox(height: 24),

        _buildLabel('Livestock Inventory'),
        const SizedBox(height: 8),
        _buildTextField(
          _livestockController,
          'e.g. Swine, Chicken, Cattle',
          prefixIcon: Icons.pets_outlined,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? _primary : _border),
          boxShadow: selected ? [
            BoxShadow(
              color: _primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
        _buildSectionTitle('Biometric Scan', Icons.face_unlock_rounded),
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
                        color: (_faceScanned ? _primary : _muted).withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
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
                              color: _primary.withOpacity(0.4),
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
        _buildSectionTitle('Identity Proof', Icons.badge_rounded),
        const SizedBox(height: 16),
        
        Text(
          'Upload a clear photo of your government-issued ID',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, 
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        // Upload box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ]
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
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: _primary, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'ID Document Captured',
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('REPLACE ID', style: GoogleFonts.plusJakartaSans(color: _muted, fontWeight: FontWeight.w700)),
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
                        Icons.cloud_upload_outlined,
                        size: 32,
                        color: _primary.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attach Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG or PDF formats accepted',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUploadOption(
                            Icons.camera_alt_rounded,
                            'Camera',
                            onTap: () => _handleIdUpload('camera'),
                            isActive: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildUploadOption(
                            Icons.photo_library_rounded,
                            'Gallery',
                            onTap: () => _handleIdUpload('files'),
                            isActive: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.blue[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Accepted IDs: National ID, Driver\'s License, Passport, or Barangay ID.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildUploadOption(IconData icon, String label, {required VoidCallback onTap, required bool isActive}) {
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
                            color: _muted.withOpacity(0.3),
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() => _signaturePoints.add(details.localPosition));
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
                      icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                      label: Text('CLEAR', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
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
      onTap: () => setState(() => _certificationAccepted = !_certificationAccepted),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _certificationAccepted ? _primary.withOpacity(0.05) : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _certificationAccepted ? _primary : _border),
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
                border: Border.all(color: _certificationAccepted ? _primary : _border, width: 2),
              ),
              child: _certificationAccepted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I certify that all information provided is accurate. I understand that misrepresentation may lead to rejection.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _dark.withOpacity(0.8),
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
                  color: _primary.withOpacity(0.3),
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
                      child: CircularProgressIndicator(
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
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _dark,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
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
            color: _muted.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, size: 20, color: _muted.withOpacity(0.6))
              : null,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 22, color: _primary.withOpacity(0.7))
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
          color: _muted.withOpacity(0.5),
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
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: _primary)),
          child: child!,
        );
      },
    );
    if (date != null) {
      _birthDateController.text =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Future<void> _handleFaceScan() async {
    final path = await context.push<String>(AppRoutes.faceCapture);
    if (path != null && mounted) {
      setState(() {
        _faceScanned = true;
        _faceImagePath = path;
      });
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

  Future<void> _handleIdUpload(String source) async {
    try {
      final XFile? image;
      if (source == 'camera') {
        image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.rear,
        );
      } else {
        image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
      }
      if (image != null && mounted) {
        setState(() {
          _idUploaded = true;
          _idImagePath = image!.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID uploaded successfully via $source!'),
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
        _showError('Failed to pick image: $e');
      }
    }
  }

  void _handleNext() {
    // Validate current step
    if (_currentStep == 0) {
      if (_addressController.text.trim().isEmpty) {
        _showError('Please enter your residential address');
        return;
      }
      if (_farmNameController.text.trim().isEmpty) {
        _showError('Please enter your farm name');
        return;
      }
    } else if (_currentStep == 1) {
      if (!_faceScanned) {
        _showError('Please complete the face scan');
        return;
      }
      if (!_idUploaded) {
        _showError('Please upload a valid ID');
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
    _registration.birthDate = _birthDateController.text.trim();
    _registration.residentialAddress = _addressController.text.trim();
    _registration.farmName = _farmNameController.text.trim();
    _registration.specialty = _specialtyController.text.trim();
    _registration.cropTypes = _selectedCrops.toList();
    _registration.livestock = _livestockController.text.trim();
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
      await SupabaseDB.submitFarmerRegistration(
        userId: auth.userId,
        registration: _registration,
      );

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
                    color: _primary.withOpacity(0.1),
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
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
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
