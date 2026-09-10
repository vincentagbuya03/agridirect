import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agridirect/shared/localization/farmer_locale_service.dart';
import 'package:agridirect/shared/localization/farmer_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('FarmerStrings returns English by default and Filipino when requested', () {
    expect(
      FarmerStrings.get('complete_profile', lang: 'en'),
      'Complete Your Profile',
    );
    expect(
      FarmerStrings.get('complete_profile', lang: 'fil'),
      'Kumpletuhin ang Iyong Profile',
    );
    expect(
      FarmerStrings.get('switch_to_farmer', lang: 'fil'),
      'Pumunta sa Tindahan ng Magsasaka',
    );
  });

  test('FarmerLocaleService toggles and notifies listeners', () async {
    final service = FarmerLocaleService();
    await service.init();
    expect(service.isFilipino, false);

    bool notified = false;
    void listener() {
      notified = true;
    }

    service.addListener(listener);

    await service.toggleLanguage();
    expect(service.isFilipino, true);
    expect(service.currentLanguage, 'fil');
    expect(notified, true);

    service.removeListener(listener);
  });
}
