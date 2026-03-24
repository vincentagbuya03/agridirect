import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/farmer_registration.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/supabase_config.dart';

/// Web Farmer Registration — Modern 3-step wizard with desktop optimization.
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
  Uint8List? _faceImageBytes;
  Uint8List? _idImageBytes;

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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Row(
              children: [
                // Left Side: Progress & Info (Sidebar)
                Container(
                  width: 300,
                  color: _primary,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.agriculture_rounded, size: 48, color: Colors.white),
                      const SizedBox(height: 24),
                      Text(
                        'Farmer\nOnboarding',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Join our community of verified sellers and grow your business.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      _buildDesktopStep(0, 'Information', 'Farm & Personal data'),
                      const SizedBox(height: 24),
                      _buildDesktopStep(1, 'Verification', 'Identity & Security'),
                      const SizedBox(height: 24),
                      _buildDesktopStep(2, 'Submission', 'Review & Signature'),
                    ],
                  ),
                ),
                // Right Side: Form
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: _buildCurrentStep(),
                        ),
                      ),
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStep(int index, String title, String subtitle) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : (isDone ? Colors.white.withOpacity(0.2) : Colors.transparent),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? _primary : Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('Personal & Farm Info', 'Tell us about yourself and your agricultural background.'),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _buildField('Birth Date', _birthDateController, 'mm/dd/yyyy', icon: Icons.calendar_today_rounded)),
            const SizedBox(width: 24),
            Expanded(child: _buildField('Years in Farming', _yearsController, 'e.g. 5+', icon: Icons.history_rounded)),
          ],
        ),
        const SizedBox(height: 24),
        _buildField('Residential Address', _addressController, 'Full home address', icon: Icons.location_on_rounded, maxLines: 2),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _buildField('Farm Name', _farmNameController, 'Branding name for your farm', icon: Icons.branding_watermark_rounded)),
            const SizedBox(width: 24),
            Expanded(child: _buildField('Specialty', _specialtyController, 'e.g. Organic, Grains', icon: Icons.star_rounded)),
          ],
        ),
        const SizedBox(height: 24),
        _buildField('Livestock', _livestockController, 'e.g. Cattle, Poultry', icon: Icons.pets_rounded),
        const SizedBox(height: 32),
        Text('Primary Crops', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['Rice', 'Corn', 'Vegetables', 'Fruits', 'Root Crops'].map((crop) => _buildCropChip(crop)).toList(),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('Identity Verification', 'We need to verify your identity to ensure a safe marketplace.'),
        const SizedBox(height: 48),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildUploadCard(
                'Face Capture',
                'Take a clear selfie for biometric verification.',
                Icons.face_unlock_rounded,
                _faceScanned,
                () => _handleCapture('face'),
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: _buildUploadCard(
                'Valid ID',
                'Upload a government-issued identification document.',
                Icons.badge_rounded,
                _idUploaded,
                () => _handleCapture('id'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('Review & Sign', 'Almost there! Provide your education and farming history.'),
        const SizedBox(height: 32),
        _buildSectionTitle('Education'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildField('Elementary', _elementaryController, 'School Name')),
            const SizedBox(width: 16),
            Expanded(child: _buildField('High School', _highSchoolController, 'School Name')),
            const SizedBox(width: 16),
            Expanded(child: _buildField('College', _collegeController, 'Degree / University')),
          ],
        ),
        const SizedBox(height: 32),
        _buildField('Farming History', _farmingHistoryController, 'Describe your experience...', maxLines: 3),
        const SizedBox(height: 32),
        _buildSectionTitle('E-Signature'),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Stack(
            children: [
              if (_signaturePoints.isEmpty)
                Center(child: Text('Draw your signature here', style: TextStyle(color: _muted.withOpacity(0.4)))),
              GestureDetector(
                onPanUpdate: (d) => setState(() => _signaturePoints.add(d.localPosition)),
                onPanEnd: (_) => _signaturePoints.add(null),
                child: CustomPaint(painter: _SignaturePainter(_signaturePoints), size: Size.infinite),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                  onPressed: () => setState(() => _signaturePoints.clear()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildCertificationCheckbox(),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: _dark)),
        const SizedBox(height: 8),
        Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _muted)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 1.2));
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {IconData? icon, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20, color: _primary) : null,
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCropChip(String crop) {
    final selected = _selectedCrops.contains(crop);
    return ChoiceChip(
      label: Text(crop),
      selected: selected,
      onSelected: (val) => setState(() => val ? _selectedCrops.add(crop) : _selectedCrops.remove(crop)),
      selectedColor: _primary,
      labelStyle: TextStyle(color: selected ? Colors.white : _dark, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildUploadCard(String title, String subtitle, IconData icon, bool done, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: done ? _primary.withOpacity(0.05) : _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: done ? _primary : _border, width: 2),
        ),
        child: Column(
          children: [
            Icon(done ? Icons.check_circle_rounded : icon, size: 48, color: done ? _primary : _muted),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationCheckbox() {
    return Row(
      children: [
        Checkbox(value: _certificationAccepted, activeColor: _primary, onChanged: (v) => setState(() => _certificationAccepted = v!)),
        const Expanded(child: Text('I certify that all information is accurate and correct.')),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          GestureDetector(
            onTap: _isSubmitting ? null : (isLast ? _handleSubmit : () => setState(() => _currentStep++)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _accent]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    isLast ? 'Submit Application' : 'Next Step',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCapture(String type) async {
    // In a real web app, we'd use image_picker_web or similar. For now, simulate.
    setState(() {
      if (type == 'face') _faceScanned = true;
      if (type == 'id') _idUploaded = true;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_certificationAccepted) return;
    setState(() => _isSubmitting = true);
    
    _registration.farmName = _farmNameController.text.trim();
    _registration.specialty = _specialtyController.text.trim();
    _registration.birthDate = _birthDateController.text.trim();
    _registration.yearsOfExperience = _yearsController.text.trim();
    _registration.residentialAddress = _addressController.text.trim();
    _registration.farmingHistory = _farmingHistoryController.text.trim();
    _registration.cropTypes = _selectedCrops.toList();
    _registration.livestock = _livestockController.text.trim();
    _registration.elementary = _elementaryController.text.trim();
    _registration.highSchool = _highSchoolController.text.trim();
    _registration.college = _collegeController.text.trim();
    
    try {
      final auth = AuthService();
      await SupabaseDB.submitFarmerRegistration(
        userId: auth.userId,
        registration: _registration,
        faceImageBytes: _faceImageBytes,
        idImageBytes: _idImageBytes,
      );
      widget.onRegistrationComplete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) canvas.drawLine(points[i]!, points[i + 1]!, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
