import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/models/farmer_registration.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/supabase_config.dart';

/// Web Farmer Registration — 3-step wizard with wider layout.
/// Step 1: Personal Data & Farm Details
/// Step 2: Identity Verification (Face Scan + Valid ID)
/// Step 3: Final Submission (Education, Work, Signature)
class WebFarmerRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const WebFarmerRegistrationScreen({
    super.key,
    required this.onRegistrationComplete,
  });

  @override
  State<WebFarmerRegistrationScreen> createState() =>
      _WebFarmerRegistrationScreenState();
}

class _WebFarmerRegistrationScreenState
    extends State<WebFarmerRegistrationScreen> {
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
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _yearsController = TextEditingController();
  final _addressController = TextEditingController();
  final _livestockController = TextEditingController();
  final Set<String> _selectedCrops = {};

  // Step 3 controllers
  final _elementaryController = TextEditingController();
  final _highSchoolController = TextEditingController();
  final _collegeController = TextEditingController();
  final _farmingHistoryController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  bool _certificationAccepted = false;

  // Step 2 state
  bool _faceScanned = false;
  bool _idUploaded = false;
  Uint8List? _faceImageBytes;
  Uint8List? _idImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  // Signature
  final List<Offset?> _signaturePoints = [];

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _yearsController.dispose();
    _addressController.dispose();
    _livestockController.dispose();
    _elementaryController.dispose();
    _highSchoolController.dispose();
    _collegeController.dispose();
    _farmingHistoryController.dispose();
    _experienceYearsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              _buildAppBar(),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ───
  Widget _buildAppBar() {
    final titles = [
      'Farmer Registration',
      'Identity Verification',
      'Final Submission',
    ];
    final subtitles = ['', 'STEP 2 OF 3', 'STEP 3 OF 3'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 0),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back, color: _dark, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titles[_currentStep],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitles[_currentStep].isNotEmpty)
                Text(
                  subtitles[_currentStep],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: 1,
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
    final labels = ['Personal', 'Business', 'Review'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i <= _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i <= _currentStep ? _primary : _border,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive ? _primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? _primary : _border,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : _muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCurrent ? _primary : _muted,
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
  // STEP 1
  // ═══════════════════════════════════════════
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.person, color: _primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Personal Data',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildLabel('Full Name'),
        const SizedBox(height: 8),
        _buildTextField(_nameController, 'Enter your full name'),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Birth Date'),
                  const SizedBox(height: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _pickBirthDate,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          _birthDateController,
                          'mm/dd/yyyy',
                          suffixIcon: Icons.calendar_today,
                        ),
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
          maxLines: 3,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Icon(Icons.agriculture_rounded, color: _primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Farm Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildLabel('Farming Area (Crop Types)'),
        const SizedBox(height: 12),
        _buildCropCheckbox('Rice', '🌾'),
        const SizedBox(height: 10),
        _buildCropCheckbox('Corn', '🌽'),
        const SizedBox(height: 10),
        _buildCropCheckbox('Vegetables', '🌶️'),
        const SizedBox(height: 20),
        _buildLabel('Livestock'),
        const SizedBox(height: 8),
        _buildTextField(
          _livestockController,
          'e.g. Swine, Chicken, Cow',
          prefixIcon: Icons.pets,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2
  // ═══════════════════════════════════════════
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Face Scan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Position your face in the circle for biometric scanning',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _handleFaceScan,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8F5E9),
                  border: Border.all(
                    color: _faceScanned ? _primary : _border,
                    width: 3,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: _faceScanned && _faceImageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _faceImageBytes!,
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
                            color: _muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click to Scan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_faceScanned)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() {
                _faceScanned = false;
                _faceImageBytes = null;
              }),
              icon: Icon(Icons.camera_alt, color: _primary, size: 18),
              label: Text(
                'Retake Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
        Text(
          'Upload Valid ID',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload a clear photo of your government-issued ID',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: _idUploaded
              ? Column(
                  children: [
                    if (_idImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _idImageBytes!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Icon(Icons.check_circle, color: _primary, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'ID Uploaded Successfully',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _idUploaded = false;
                        _idImageBytes = null;
                      }),
                      child: Text(
                        'Upload Again',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 44,
                      color: _muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Capture or Upload ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ensure all text and your photo are clearly visible on the ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: _muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUploadButton(
                          Icons.camera_alt,
                          'Camera',
                          filled: true,
                          onTap: () => _handleIdUpload('camera'),
                        ),
                        const SizedBox(width: 12),
                        _buildUploadButton(
                          Icons.folder_open,
                          'Files',
                          filled: false,
                          onTap: () => _handleIdUpload('files'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted Documents:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Farmer's ID, Driver's License, National ID, or Passport.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUploadButton(
    IconData icon,
    String label, {
    required bool filled,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : _dark),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : _dark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 3
  // ═══════════════════════════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certification & Review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    Text(
                      'Please verify your educational and professional details before final submission.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionHeader('EDUCATIONAL BACKGROUND'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallLabel('ELEMENTARY'),
              _buildUnderlineField(
                _elementaryController,
                'Name of School / Year Graduated',
              ),
              const SizedBox(height: 18),
              _buildSmallLabel('HIGH SCHOOL'),
              _buildUnderlineField(
                _highSchoolController,
                'Name of School / Year Graduated',
              ),
              const SizedBox(height: 18),
              _buildSmallLabel('COLLEGE'),
              _buildUnderlineField(_collegeController, 'Degree / University'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionHeader('WORK EXPERIENCE'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmallLabel('PREVIOUS EMPLOYMENT / FARMING HISTORY'),
              _buildUnderlineField(
                _farmingHistoryController,
                'Describe your relevant experience...',
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              _buildSmallLabel('NO. OF YEARS IN FARMING'),
              _buildUnderlineField(_experienceYearsController, 'e.g. 10'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionHeader('ELECTRONIC SIGNATURE'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(
                        () => _signaturePoints.add(details.localPosition),
                      );
                    },
                    onPanEnd: (_) => _signaturePoints.add(null),
                    child: CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _WebSignaturePainter(_signaturePoints),
                    ),
                  ),
                ),
              ),
              if (_signaturePoints.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Sign inside the box',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: _muted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _signaturePoints.clear()),
                    icon: Icon(Icons.refresh, size: 16, color: _muted),
                    label: Text(
                      'CLEAR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(
              () => _certificationAccepted = !_certificationAccepted,
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
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I hereby certify that the information provided above is true and correct to the best of my knowledge and belief.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: _muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Bottom Button ───
  Widget _buildBottomButton() {
    final isLastStep = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: MouseRegion(
          cursor: _isSubmitting
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
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
                            isLastStep
                                ? Icons.send_rounded
                                : Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════
  Widget _buildLabel(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _dark,
    ),
  );

  Widget _buildSectionHeader(String text) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 2,
        ),
      ),
    ],
  );

  Widget _buildSmallLabel(String text) => Padding(
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: _muted.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, size: 18, color: _muted)
              : null,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: _muted)
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

  Widget _buildCropCheckbox(String label, String emoji) {
    final selected = _selectedCrops.contains(label);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() {
          if (selected) {
            _selectedCrops.remove(label);
          } else {
            _selectedCrops.add(label);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _primary.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _primary : _border),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _primary : Colors.white,
                  border: Border.all(
                    color: selected ? _primary : _border,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
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
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (date != null) {
      _birthDateController.text =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Future<void> _handleFaceScan() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _faceScanned = true;
          _faceImageBytes = bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Face captured successfully!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Camera not available. Please upload a photo.');
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
        final bytes = await image.readAsBytes();
        setState(() {
          _idUploaded = true;
          _idImageBytes = bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID uploaded successfully via $source!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to pick image: $e');
    }
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your full name');
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        _showError('Please enter your residential address');
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

    _registration.fullName = _nameController.text.trim();
    _registration.birthDate = _birthDateController.text.trim();
    _registration.yearsInFarming = _yearsController.text.trim();
    _registration.residentialAddress = _addressController.text.trim();
    _registration.cropTypes = _selectedCrops.toList();
    _registration.livestock = _livestockController.text.trim();
    _registration.facePhotoPath = _faceScanned ? 'face_captured_web' : null;
    _registration.validIdPath = _idUploaded ? 'id_uploaded_web' : null;
    _registration.elementary = _elementaryController.text.trim();
    _registration.highSchool = _highSchoolController.text.trim();
    _registration.college = _collegeController.text.trim();
    _registration.farmingHistory = _farmingHistoryController.text.trim();
    _registration.yearsOfExperience = _experienceYearsController.text.trim();
    _registration.hasSigned = _signaturePoints.isNotEmpty;
    _registration.certificationAccepted = _certificationAccepted;

    try {
      final auth = AuthService();
      await SupabaseDB.submitFarmerRegistration(
        userId: auth.userId,
        registration: _registration,
      );
      await auth.startSelling();

      if (mounted) {
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
                  'Your farmer registration has been submitted for approval. You can now access the Farmer Dashboard.',
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
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
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
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Registration failed: $e');
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

class _WebSignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _WebSignaturePainter(this.points);

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
  bool shouldRepaint(covariant _WebSignaturePainter oldDelegate) => true;
}
