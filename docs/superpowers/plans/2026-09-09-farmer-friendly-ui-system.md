# Farmer-Friendly UI System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a high-contrast, bilingual, visual-first UI system tailored for Filipino farmers, including an instant mode switcher capsule and an overhauled profile completion flow.

**Architecture:** A lightweight `FarmerLocaleService` (ChangeNotifier backed by SharedPreferences) drives reactive bilingual English ⇄ Filipino copy with zero reload latency. A dedicated `FarmerTheme` provides sunlight-optimized contrast, 56px+ tap targets, and 16px+ typography. Reusable farmer components (`FarmerButton`, `FarmerTextField`, `FarmerStepCard`, `FarmerLanguageToggle`, `FarmerModeSwitcherCapsule`) are integrated into the Mobile/Web headers and the profile completion screens.

**Tech Stack:** Flutter / Dart, Google Fonts (Plus Jakarta Sans & Inter), SharedPreferences, Supabase Auth.

## Global Constraints

- Minimum touch target height for primary farmer actions: 56px.
- Minimum body text font size: 15–16px.
- Text contrast must meet or exceed WCAG AA (minimum 4.5:1 ratio, using `#0F172A` / `#14532D` against light backgrounds).
- Bilingual toggle must switch strings immediately without page reload or network delay.
- Existing Supabase auth, role logic, and navigation routes (`AppRoutes`) must be preserved without breaking changes.

---

### Task 1: Farmer Localization Engine (`FarmerLocaleService` & `FarmerStrings`)

**Files:**
- Create: `lib/shared/localization/farmer_strings.dart`
- Create: `lib/shared/localization/farmer_locale_service.dart`
- Test: `test/shared/localization/farmer_locale_service_test.dart`

**Interfaces:**
- Consumes: `package:shared_preferences/shared_preferences.dart`
- Produces: 
  - `FarmerLocaleService.instance`: singleton with `String get currentLanguage`, `bool get isFilipino`, `Future<void> toggleLanguage()`, `Future<void> setLanguage(String lang)`
  - `FarmerStrings.get(String key, {String? lang})`: returns localized string for given key ('en' or 'fil')

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/localization/farmer_locale_service_test.dart
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
    expect(FarmerStrings.get('complete_profile', lang: 'en'), 'Complete Your Profile');
    expect(FarmerStrings.get('complete_profile', lang: 'fil'), 'Kumpletuhin ang Iyong Profile');
    expect(FarmerStrings.get('switch_to_farmer', lang: 'fil'), 'Pumunta sa Tindahan ng Magsasaka');
  });

  test('FarmerLocaleService toggles and notifies listeners', () async {
    final service = FarmerLocaleService();
    await service.init();
    expect(service.isFilipino, false);

    bool notified = false;
    service.addListener(() {
      notified = true;
    });

    await service.toggleLanguage();
    expect(service.isFilipino, true);
    expect(service.currentLanguage, 'fil');
    expect(notified, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/localization/farmer_locale_service_test.dart`  
Expected: FAIL (files do not exist yet)

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/shared/localization/farmer_strings.dart
class FarmerStrings {
  static const Map<String, Map<String, String>> _localized = {
    'complete_profile': {
      'en': 'Complete Your Profile',
      'fil': 'Kumpletuhin ang Iyong Profile',
    },
    'complete_profile_sub': {
      'en': 'Verify your mobile phone and set your password to activate your account.',
      'fil': 'I-kumpirma ang iyong mobile number at gumawa ng password para magamit ang account.',
    },
    'phone_step_title': {
      'en': '1. Mobile Phone Number',
      'fil': '1. Numero ng Mobile Phone',
    },
    'password_step_title': {
      'en': '2. Create Your Password',
      'fil': '2. Gumawa ng Password',
    },
    'password_hint': {
      'en': 'Enter at least 6 characters',
      'fil': 'Maglagay ng kahit 6 na letra o numero',
    },
    'confirm_password_hint': {
      'en': 'Re-enter your password to confirm',
      'fil': 'Ulitin ang password para makasiguro',
    },
    'create_account_cta': {
      'en': 'Create Account & Enter Farm',
      'fil': 'Gawin ang Account at Pumasok',
    },
    'logout_sign_in_later': {
      'en': 'Log Out & Sign In Later',
      'fil': 'Mag-Log Out Muna',
    },
    'switch_to_farmer': {
      'en': 'Go to Farmer Store',
      'fil': 'Pumunta sa Tindahan ng Magsasaka',
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
      'fil': 'Hindi magkatugma ang passwords',
    },
    'phone_required': {
      'en': 'Please enter a valid, unique Philippine mobile number',
      'fil': 'Mangyaring maglagay ng wastong Philippine mobile number',
    },
    'password_required': {
      'en': 'Please create and confirm your password',
      'fil': 'Mangyaring gumawa at kumpirmahin ang iyong password',
    },
  };

  static String get(String key, {String? lang}) {
    final language = lang ?? 'en';
    return _localized[key]?[language] ?? _localized[key]?['en'] ?? key;
  }
}
```

```dart
// lib/shared/localization/farmer_locale_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'farmer_strings.dart';

class FarmerLocaleService extends ChangeNotifier {
  static final FarmerLocaleService _instance = FarmerLocaleService._internal();
  factory FarmerLocaleService() => _instance;
  static FarmerLocaleService get instance => _instance;

  FarmerLocaleService._internal();

  static const String _prefKey = 'farmer_app_language';
  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;
  bool get isFilipino => _currentLanguage == 'fil';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString(_prefKey) ?? 'en';
      notifyListeners();
    } catch (_) {
      _currentLanguage = 'en';
    }
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next = _currentLanguage == 'en' ? 'fil' : 'en';
    await setLanguage(next);
  }

  String t(String key) => FarmerStrings.get(key, lang: _currentLanguage);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/localization/farmer_locale_service_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/localization/ test/shared/localization/
git commit -m "feat(l10n): implement FarmerLocaleService and FarmerStrings dictionary"
```

---

### Task 2: Farmer-First Design System Tokens & Base Widgets

**Files:**
- Create: `lib/shared/styles/farmer_theme.dart`
- Create: `lib/shared/widgets/farmer/farmer_button.dart`
- Create: `lib/shared/widgets/farmer/farmer_text_field.dart`
- Create: `lib/shared/widgets/farmer/farmer_step_card.dart`
- Create: `lib/shared/widgets/farmer/farmer_language_toggle.dart`
- Test: `test/shared/widgets/farmer/farmer_widgets_test.dart`

**Interfaces:**
- Consumes: `FarmerLocaleService`, `GoogleFonts`
- Produces:
  - `FarmerTheme`: design tokens (`primaryForest`, `actionGreen`, `accentGold`, `textCharcoal`, `minTouchHeight: 56.0`)
  - `FarmerButton`: 56px height, high-contrast, icon + text
  - `FarmerTextField`: 54px height, high-contrast border, prefix icon, optional suffix icon
  - `FarmerStepCard`: container with step badge, icon, and inner child
  - `FarmerLanguageToggle`: visual capsule toggle (`🇵🇭 Filipino | 🇺🇸 English`)

- [ ] **Step 1: Write the failing widget test**

```dart
// test/shared/widgets/farmer/farmer_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/localization/farmer_locale_service.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_button.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_language_toggle.dart';

void main() {
  testWidgets('FarmerButton renders with minimum 56px height and label', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerButton(
            label: 'Magpatuloy',
            icon: Icons.check,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    final buttonFinder = find.byType(FarmerButton);
    expect(buttonFinder, findsOneWidget);
    final size = tester.getSize(buttonFinder);
    expect(size.height, greaterThanOrEqualTo(56.0));

    await tester.tap(buttonFinder);
    expect(tapped, true);
  });

  testWidgets('FarmerLanguageToggle toggles language on tap', (tester) async {
    final service = FarmerLocaleService.instance;
    await service.setLanguage('en');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FarmerLanguageToggle(),
        ),
      ),
    );

    expect(find.textContaining('Filipino'), findsOneWidget);
    await tester.tap(find.byType(FarmerLanguageToggle));
    await tester.pumpAndSettle();
    expect(service.isFilipino, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/farmer/farmer_widgets_test.dart`  
Expected: FAIL (widgets not defined)

- [ ] **Step 3: Write minimal implementation**

Implement:
1. `lib/shared/styles/farmer_theme.dart` with colors and metrics.
2. `lib/shared/widgets/farmer/farmer_button.dart`.
3. `lib/shared/widgets/farmer/farmer_text_field.dart`.
4. `lib/shared/widgets/farmer/farmer_step_card.dart`.
5. `lib/shared/widgets/farmer/farmer_language_toggle.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/farmer/farmer_widgets_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/styles/farmer_theme.dart lib/shared/widgets/farmer/ test/shared/widgets/farmer/
git commit -m "feat(ui): add FarmerTheme tokens and core farmer widgets"
```

---

### Task 3: Never-Lost Farmer Mode Switcher Capsule (Mobile & Web)

**Files:**
- Create: `lib/shared/widgets/farmer/farmer_mode_switcher_capsule.dart`
- Modify: `lib/mobile/screens/consumer/customer_profile_screen.dart`
- Modify: `lib/web/widgets/ecom/web_ecom_header.dart`

**Interfaces:**
- Consumes: `AuthService`, `FarmerLocaleService`, `AppRoutes`
- Produces: `FarmerModeSwitcherCapsule` (compact & expanded variants with clear icon and high-contrast styling)

- [ ] **Step 1: Write widget test for FarmerModeSwitcherCapsule**

```dart
// test/shared/widgets/farmer/farmer_mode_switcher_capsule_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_mode_switcher_capsule.dart';

void main() {
  testWidgets('FarmerModeSwitcherCapsule renders correctly and fires callback', (tester) async {
    bool switched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerModeSwitcherCapsule(
            onSwitch: () => switched = true,
          ),
        ),
      ),
    );

    expect(find.byType(FarmerModeSwitcherCapsule), findsOneWidget);
    await tester.tap(find.byType(FarmerModeSwitcherCapsule));
    expect(switched, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/widgets/farmer/farmer_mode_switcher_capsule_test.dart`  
Expected: FAIL

- [ ] **Step 3: Implement FarmerModeSwitcherCapsule and integrate into Mobile & Web**

- Create `lib/shared/widgets/farmer/farmer_mode_switcher_capsule.dart` with prominent emerald pill design, seedling icon (`Icons.eco_rounded` or `Icons.storefront_rounded`), and bilingual text.
- Modify `customer_profile_screen.dart` to render this prominent switcher card prominently at the top when `auth.isSeller`.
- Modify `web_ecom_header.dart` to display the direct mode switch pill in the top navigation bar when `auth.isSeller`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/widgets/farmer/farmer_mode_switcher_capsule_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/farmer/farmer_mode_switcher_capsule.dart lib/mobile/screens/consumer/customer_profile_screen.dart lib/web/widgets/ecom/web_ecom_header.dart test/shared/widgets/farmer/farmer_mode_switcher_capsule_test.dart
git commit -m "feat(ux): implement prominent FarmerModeSwitcherCapsule on mobile and web"
```

---

### Task 4: Overhaul Web Profile Completion Screen (`WebCompleteProfileScreen`)

**Files:**
- Modify: `lib/web/screens/auth/web_complete_profile_screen.dart`

**Interfaces:**
- Consumes: `FarmerLocaleService`, `FarmerButton`, `FarmerTextField`, `FarmerStepCard`, `FarmerLanguageToggle`, `DistinctivePhoneInput`, `AuthService`
- Produces: Accessible, bilingual 2-step profile completion screen with 56px+ touch targets and high sunlight contrast.

- [ ] **Step 1: Inspect and verify existing tests**

Run: `flutter test test/` to verify baseline passes.

- [ ] **Step 2: Refactor WebCompleteProfileScreen**

- Add `FarmerLanguageToggle` to the top-right header of the card.
- Listen to `FarmerLocaleService.instance` using `ListenableBuilder` so all text updates reactively upon toggle.
- Wrap Phone input in `FarmerStepCard` (Step 1: Phone Number).
- Wrap Password inputs in `FarmerStepCard` (Step 2: Password).
- Replace submit button with `FarmerButton` (56px tall, icon + bold text).
- Use `FarmerStrings.get(...)` for all user-facing labels and error snackbars.

- [ ] **Step 3: Run Flutter analyze and widget tests**

Run: `flutter analyze lib/web/screens/auth/web_complete_profile_screen.dart`  
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/web/screens/auth/web_complete_profile_screen.dart
git commit -m "feat(web): redesign WebCompleteProfileScreen with Farmer-First bilingual UI"
```

---

### Task 5: Full Project Verification & Integration Checks

**Files:**
- Check: All modified and new files across `lib/` and `test/`

- [ ] **Step 1: Run complete test suite**

Run: `flutter test`  
Expected: All tests pass.

- [ ] **Step 2: Run Flutter analyze across entire project**

Run: `flutter analyze`  
Expected: 0 errors.

- [ ] **Step 3: Commit final plan deliverable**

```bash
git add -A
git commit -m "chore: complete Phase 1 farmer-first UI system integration"
```
