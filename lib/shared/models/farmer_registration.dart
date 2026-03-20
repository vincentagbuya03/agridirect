/// Model for farmer registration data
class FarmerRegistration {
  // Step 1: Personal Data
  String fullName;
  String birthDate;
  String yearsInFarming;
  String residentialAddress;

  // Step 1: Farm Details
  List<String> cropTypes; // Rice, Corn, Vegetables, etc.
  String livestock;

  // Step 2: Identity Verification (OPTIONAL)
  String? facePhotoPath;
  String? validIdPath;

  // Step 3: Final Submission (OPTIONAL)
  String elementary;
  String highSchool;
  String college;
  String farmingHistory;
  String yearsOfExperience;
  bool hasSigned;
  bool certificationAccepted;

  FarmerRegistration({
    this.fullName = '',
    this.birthDate = '',
    this.yearsInFarming = '',
    this.residentialAddress = '',
    this.cropTypes = const [],
    this.livestock = '',
    this.facePhotoPath,
    this.validIdPath,
    this.elementary = '',
    this.highSchool = '',
    this.college = '',
    this.farmingHistory = '',
    this.yearsOfExperience = '',
    this.hasSigned = false,
    this.certificationAccepted = false,
  });

  /// Convert to JSON for farmer_registrations table (3NF)
  /// Education, crop types, and livestock are stored in separate tables
  Map<String, dynamic> toJson() => {
        'birth_date': birthDate,
        'years_of_experience': int.tryParse(yearsOfExperience) ?? int.tryParse(yearsInFarming) ?? 0,
        'residential_address': residentialAddress,
        'face_photo_path': facePhotoPath,
        'valid_id_path': validIdPath,
        'farming_history': farmingHistory,
        'certification_accepted': certificationAccepted,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

  /// Education levels for farmer_education table
  List<Map<String, String>> toEducationRows() {
    final rows = <Map<String, String>>[];
    if (elementary.isNotEmpty) rows.add({'level': 'elementary', 'school_name': elementary});
    if (highSchool.isNotEmpty) rows.add({'level': 'high_school', 'school_name': highSchool});
    if (college.isNotEmpty) rows.add({'level': 'college', 'school_name': college});
    return rows;
  }

  /// Crop types for farmer_crop_types table
  List<Map<String, String>> toCropTypeRows() {
    return cropTypes.where((c) => c.isNotEmpty).map((c) => {'crop_type': c}).toList();
  }

  /// Livestock for farmer_livestock table
  List<Map<String, String>> toLivestockRows() {
    if (livestock.isEmpty) return [];
    return livestock.split(',').map((l) => {'livestock_type': l.trim()}).where((m) => m['livestock_type']!.isNotEmpty).toList();
  }
}
