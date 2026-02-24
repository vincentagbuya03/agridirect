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

  // Step 2: Identity Verification
  String? facePhotoPath;
  String? validIdPath;

  // Step 3: Final Submission
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

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'birth_date': birthDate,
        'years_in_farming': yearsInFarming,
        'residential_address': residentialAddress,
        'crop_types': cropTypes,
        'livestock': livestock,
        'face_photo_path': facePhotoPath,
        'valid_id_path': validIdPath,
        'elementary': elementary,
        'high_school': highSchool,
        'college': college,
        'farming_history': farmingHistory,
        'years_of_experience': yearsOfExperience,
        'certification_accepted': certificationAccepted,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
}
