/// Bilingual dictionary for Farmer-First UI components.
/// Provides English ('en') and natural conversational Filipino ('fil').
class FarmerStrings {
  static const Map<String, Map<String, String>> _localized = {
    'complete_profile': {
      'en': 'Complete Your Profile',
      'fil': 'Kumpletuhin ang Iyong Profile',
    },
    'complete_profile_sub': {
      'en':
          'Verify your mobile phone and set your password to activate your account.',
      'fil':
          'I-kumpirma ang iyong mobile number at gumawa ng password para magamit ang account.',
    },
    'phone_step_title': {
      'en': '1. Mobile Phone Number',
      'fil': '1. Numero ng Mobile Phone',
    },
    'phone_step_sub': {
      'en': 'Enter your active Philippine mobile number (+63)',
      'fil': 'Ilagay ang iyong aktibong mobile number (+63)',
    },
    'password_step_title': {
      'en': '2. Create Your Password',
      'fil': '2. Gumawa ng Lihim na Salita (Password)',
    },
    'password_step_sub': {
      'en': 'Choose a strong password to protect your account',
      'fil': 'Pumili ng ligtas na password para protektahan ang account',
    },
    'password_label': {
      'en': 'Account Password *',
      'fil': 'Password ng Account *',
    },
    'password_hint': {
      'en': 'Enter at least 6 characters',
      'fil': 'Maglagay ng kahit 6 na letra o numero',
    },
    'confirm_password_label': {
      'en': 'Confirm Password *',
      'fil': 'Ulitin ang Password *',
    },
    'confirm_password_hint': {
      'en': 'Re-enter your password to confirm',
      'fil': 'Ulitin ang password para makasiguro',
    },
    'create_account_cta': {
      'en': 'Create Account & Enter Farm',
      'fil': 'Gawin ang Account at Pumasok',
    },
    'saving_account': {
      'en': 'Setting up your account...',
      'fil': 'Inihahanda ang iyong account...',
    },
    'logout_sign_in_later': {
      'en': 'Log Out & Sign In Later',
      'fil': 'Mag-Log Out Muna',
    },
    'switch_to_farmer': {
      'en': 'Go to Farmer Store',
      'fil': 'Tindahan ng Magsasaka',
    },
    'switch_to_consumer': {
      'en': 'Switch to Customer View',
      'fil': 'Lumipat sa Pamilihan',
    },
    'farmer_mode_badge': {
      'en': 'FARMER STORE',
      'fil': 'TINDAHAN NG MAGSASAKA',
    },
    'consumer_mode_badge': {
      'en': 'BUYER VIEW',
      'fil': 'PAMILIHAN',
    },
    'verified_badge': {
      'en': 'Verified & Ready',
      'fil': 'Kumpirmado at Handa na',
    },
    'passwords_mismatch': {
      'en': 'Passwords do not match',
      'fil': 'Hindi magkatugma ang dalawang password',
    },
    'phone_required': {
      'en': 'Please enter a valid, unique Philippine mobile number',
      'fil': 'Mangyaring maglagay ng wastong Philippine mobile number',
    },
    'password_required': {
      'en': 'Please create and confirm your password',
      'fil': 'Mangyaring gumawa at kumpirmahin ang iyong password',
    },
    'logout_confirm_title': {
      'en': 'Log Out',
      'fil': 'Mag-Log Out',
    },
    'logout_confirm_body': {
      'en':
          'Are you sure you want to log out? You can sign in again later to complete your profile.',
      'fil':
          'Sigurado ka bang nais mong mag-log out? Maaari kang mag-sign in muli mamaya upang kumpletuhin ang profile.',
    },
    'lang_toggle_en': {
      'en': 'English',
      'fil': 'English',
    },
    'lang_toggle_fil': {
      'en': 'Filipino',
      'fil': 'Filipino',
    },
  };

  /// Retrieve localized string for [key] in specified [lang] or fallback to English.
  static String get(String key, {String? lang}) {
    final language = lang ?? 'en';
    return _localized[key]?[language] ?? _localized[key]?['en'] ?? key;
  }
}
