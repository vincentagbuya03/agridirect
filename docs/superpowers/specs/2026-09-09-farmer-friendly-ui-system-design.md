# Farmer-First UI & Experience Design Specification

**Date:** 2026-09-09  
**Status:** Approved  
**Target:** AgriDirect (Web & Mobile Flutter Platform)  
**Phase:** Phase 1 – Foundation, Bilingual Engine, Farmer Mode Switcher & Profile Completion  

---

## 1. Executive Summary & Problem Statement

### 1.1 The Challenge
The existing AgriDirect user interface features modern SaaS aesthetics (Plus Jakarta Sans, subtle gray text, compact forms, and hamburger menus). While visually modern to urban tech workers, it introduces significant friction for Filipino agricultural producers:
1. **Low Contrast & Eye Fatigue**: Sub-14px gray text (`#64748B`) is illegible in outdoor tropical sunlight and straining for aging eyes (average farmer age in PH: 53–57).
2. **Small Tap Targets**: 40–48px buttons lead to mis-taps by users with work-worn or wet hands.
3. **Complex English Terminology**: Phrases like *"Finalize Registration"* or *"E.164 verification"* cause cognitive overload.
4. **Getting "Trapped" in Consumer Mode**: Farmers who buy supplies or test the app in Customer/Consumer mode find it difficult to switch back to their Farmer storefront because the mode toggle is buried in a profile sub-menu with tiny 11px text.

### 1.2 The Solution
A dedicated **Farmer-First UI System** that provides:
- **Instant Bilingual Switching (English ⇄ Filipino/Tagalog)** without reloading the app.
- **Visual-First & Icon-Guided Components** with large agricultural symbols, 56px+ touch targets, and high outdoor sunlight contrast.
- **Always-Visible Mode Switcher Capsule** so verified farmers can toggle between *Customer View* and *Farmer Store* with a single tap anywhere in the app.
- **Streamlined Profile Completion** on both Web and Mobile with intuitive 2-step visual cards.

---

## 2. Target Personas & Design Principles

### 2.1 Persona: Tatay Manny (56-year-old Vegetable Farmer)
- **Device**: Mid-range Android smartphone, screen brightness often lowered to save battery or used under outdoor sunlight.
- **Language**: Prefers Tagalog / Taglish for instructional guidance; understands basic English but dislikes dense legalistic forms.
- **Key Habit**: Relies on visual icons (seeds, trucks, peso signs, green checks) to confirm what an action does before pressing.

### 2.2 Core Design Principles
1. **Sunlight Legibility**: Minimum text size of 15–16px for body copy; solid charcoal (`#0F172A`) against high-contrast backgrounds; no low-opacity grays for critical information.
2. **Work-Ready Touch Targets**: All interactive buttons, inputs, and toggles have a minimum height of **56px**.
3. **No-Jargon Bilingual Communication**: Every action is clearly labeled with respectful, plain English and natural conversational Filipino.
4. **Persistent Orientation**: The user must always know what mode they are currently in (*Tindahan ng Magsasaka* vs. *Bilihin ng Mamimili*) and have an instant 1-tap escape back to their farm dashboard.

---

## 3. Architecture & Core Components

```
lib/
├── shared/
│   ├── localization/
│   │   ├── farmer_locale_service.dart   # ChangeNotifier with persistent preference ('en' | 'fil')
│   │   └── farmer_strings.dart          # Natural bilingual dictionary
│   ├── styles/
│   │   └── farmer_theme.dart            # High-contrast colors, 56px+ dimensions, typography
│   └── widgets/
│       └── farmer/
│           ├── farmer_button.dart               # 56px+ tactile button with icon & high contrast
│           ├── farmer_text_field.dart          # 54px+ high-contrast input with clear icon prefix
│           ├── farmer_language_toggle.dart     # Pill toggle (🇵🇭 Filipino | 🇺🇸 English)
│           ├── farmer_step_card.dart           # Visual status cards with badge indicators
│           └── farmer_mode_switcher_capsule.dart # High-visibility 1-tap switcher (Consumer ⇄ Farmer)
```

### 3.1 `FarmerLocaleService` & `FarmerStrings`
* Uses Flutter `ChangeNotifier` backed by `shared_preferences`.
* Supports instantaneous switching with zero latency.
* Key terminology mappings:

| Context | English | Filipino / Tagalog |
| :--- | :--- | :--- |
| Screen Title | Complete Your Profile | Kumpletuhin ang Iyong Profile |
| Subtitle | Verify phone and set password | I-kumpirma ang numero at gumawa ng password |
| Phone Step | Mobile Phone Number | Numero ng Mobile Phone |
| Phone Verified | Verified & Active | Kumpirmado at Handa na |
| Password Step | Account Password | Lihim na Salita (Password) |
| Confirm Password | Re-type Password | Ulitin ang Password |
| Submit Button | Create Account & Enter Farm | Gumawa ng Account at Pumasok |
| Logout Option | Log Out & Sign In Later | Mag-Log Out muna |
| Farmer Switcher | Go to Farmer Store | Pumunta sa Tindahan ng Magsasaka |
| Consumer Switcher| Switch to Buyer View | Lumipat sa Mamimili |

### 3.2 `FarmerTheme` Design Tokens
* **Primary Greens**: `#064E3B` (Forest 900), `#15803D` (Green 700), `#E9F8EF` (Light Mint Surface).
* **Accent Gold / Action**: `#D97706` (Amber 600) for high-importance primary triggers.
* **Text Contrast**: `#0F172A` (Slate 900) for headlines and body text; `#334155` (Slate 700) for secondary text. Never below 4.5:1 contrast ratio.
* **Borders**: `#CBD5E1` (Slate 300) with 1.5px stroke for crisp definition in direct sunlight.
* **Touch Targets**: Height 56px, border radius 16px.

---

## 4. Feature Specifications

### 4.1 "Never-Lost" Farmer Mode Switcher
* **Condition**: User is a registered/approved farmer (`AuthService().isSeller == true`) currently navigating in **Consumer Mode**.
* **Mobile Placement**:
  * Persistent pill pinned to the top header across Customer Home and Customer Profile:
    * `[🌱 Pumunta sa Tindahan ng Magsasaka / Farmer Mode ➔]`
  * High-contrast emerald background with bold white text and a vibrant icon.
  * Tapping immediately calls `AuthService().switchToFarmerMode()`, switches role state, and redirects to the farmer dashboard without extra sub-menus.
* **Web Placement**:
  * Prominent mode switcher in the top navigation bar next to search and profile avatar:
    * Segmented pill: `[🛒 Consumer Mode] | [🌱 Farmer Mode (Tindahan)]`
  * Active state highlights the current mode with a solid green badge; inactive mode is a clickable outline button.

### 4.2 Web Profile Completion Overhaul (`WebCompleteProfileScreen`)
* **Header Language Switcher**:
  * Top right of the card features the `FarmerLanguageToggle` (`🇵🇭 Filipino | 🇺🇸 English`).
* **Visual Progress Badges**:
  * Step 1: 📱 Mobile Phone Verification (checks against unique DB records, displays a bold green badge upon success).
  * Step 2: 🔒 Password Setup (54px input, high-contrast visibility toggle, clear guidelines).
* **Large Primary Action**:
  * 58px tall button with tactile hover/press state.
* **Exit Option**:
  * Clearly labeled bottom action: *"Log Out & Sign In Later"* / *"Mag-Log Out muna"* with a prominent red door icon.

---

## 5. Verification & Testing Strategy

### 5.1 Automated Verification
* `flutter test` for `FarmerLocaleService` ensuring language switching state persists and emits updates.
* Flutter widget tests for `FarmerButton` and `FarmerLanguageToggle` ensuring touch target dimensions (>= 56px) and correct label switching on toggle.
* Flutter analyze verification (`flutter analyze`) with zero errors and warnings.

### 5.2 Manual Verification
* **Sunlight / High-Brightness Test**: Run on Chrome and mobile device/emulator with full brightness to ensure text contrast and borders remain crisp.
* **Mode Switching Flow**:
  1. Login as a farmer account.
  2. Switch to Consumer Mode.
  3. Verify the "Farmer Mode Switcher Capsule" is immediately visible on screen.
  4. Tap the capsule; verify instant transition to the Farmer Dashboard.
* **Bilingual Toggle**:
  1. Open profile completion.
  2. Toggle to Filipino; verify all labels, hints, and error alerts change to Tagalog instantly.
  3. Toggle back to English; verify instant reversal.

---

## 6. Implementation Phases

* **Phase 1 (Immediate)**:
  1. Create `FarmerLocaleService` & `FarmerStrings`.
  2. Create `FarmerTheme` tokens & reusable farmer widgets.
  3. Implement the **Persistent Farmer Mode Switcher** (Mobile & Web).
  4. Refactor `WebCompleteProfileScreen` with the new farmer-friendly components.
* **Phase 2 (Subsequent)**:
  * Mobile Farmer Core Screens: Add Product, Incoming Orders, and Sales Dashboard.
* **Phase 3 (Subsequent)**:
  * Web Farmer Management Portal and Cooperative fulfillment tables.
