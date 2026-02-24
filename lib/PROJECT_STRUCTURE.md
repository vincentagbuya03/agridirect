# ArgiDirect - Project Structure

## Overview

ArgiDirect is a Flutter application for connecting farmers and consumers. It provides a platform for farmers to sell produce directly and for consumers to purchase fresh, local produce. The app supports both mobile (iOS/Android) and web platforms with adaptive layouts.

This project follows a **clean architecture pattern** with clear separation of concerns:

- **Mobile** (`lib/mobile/`): Mobile-specific UI and navigation
- **Web** (`lib/web/`): Web-specific UI and navigation
- **Shared** (`lib/shared/`): Reusable business logic, models, services, and utilities

## Folder Structure

```
lib/
├── main.dart                          # App entry point with adaptive layout & onboarding logic
│
├── mobile/
│   ├── mobile_navigation.dart         # Bottom tab navigation shell
│   └── screens/
│       ├── auth/
│       │   ├── login_screen.dart                # Mobile login screen with clean design
│       │   ├── registration_screen.dart        # Mobile user registration screen
│       │   └── farmer_registration_screen.dart  # Farmer registration wizard
│       ├── common/
│       │   ├── loading_screen.dart              # Splash/loading animation
│       │   ├── onboarding_screen.dart           # 3-page onboarding for new users
│       │   └── face_capture_screen.dart         # Face verification for farmers
│       ├── consumer/
│       │   ├── consumer_marketplace_home.dart   # Consumer marketplace
│       │   ├── preorder_product_details.dart    # Product details/pre-order
│       │   └── profile_screen.dart              # User profile
│       └── farmer/
│           ├── farmer_sales_dashboard.dart      # Farmer dashboard
│           └── farmer_community_hub.dart        # Community/social features
│
├── web/
│   ├── web_navigation.dart            # Web layout & routing
│   └── screens/
│       ├── web_login_screen.dart           # Web login
│       ├── web_registration_screen.dart    # Web user registration
│       ├── web_farmer_registration_screen.dart  # Web farmer registration
│       ├── web_marketplace_home.dart       # Web marketplace
│       ├── web_preorder_details.dart       # Web product details
│       ├── web_profile_screen.dart         # Web profile
│       ├── web_community_hub.dart          # Web community
│       └── web_sales_dashboard.dart        # Web dashboard
│
└── shared/
    ├── data/
    │   └── app_data.dart              # Static/mock product data
    ├── models/
    │   └── farmer_registration.dart   # FarmerRegistration data model
    ├── services/
    │   ├── auth_service.dart          # Authentication & user state (Supabase)
    │   ├── onboarding_service.dart    # Onboarding tracking (SharedPreferences)
    │   └── supabase_config.dart       # Supabase init + DB operations
    └── utils/
        └── responsive.dart            # Screen-size breakpoint helpers
```

## Architecture Principles

### 1. Separation by Platform (Mobile vs Web)

- **Mobile** — Bottom navigation, touch-friendly, compact layouts
- **Web** — Sidebar/horizontal navigation, mouse/keyboard optimized, wider layouts
- Each platform has its own screen implementations

### 2. Shared Layer

- **Models**: Data structures (e.g. `FarmerRegistration`)
- **Services**:
  - `AuthService`: Manages authentication & user roles via Supabase
  - `OnboardingService`: Tracks onboarding completion via SharedPreferences
  - `SupabaseConfig`: Database operations & backend integration
- **Data**: Static/mock data used across platforms
- **Utils**: Responsive breakpoints, helper functions

### 3. Adaptive Entry Point

- `main.dart` uses `LayoutBuilder` to detect screen width
- Width > 800px → `WebNavigation`
- Width ≤ 800px → `MobileNavigation`
- First-time mobile users see 3-page onboarding before login

### 4. Authentication & Registration

- **Login Screen**: Clean, modern design with email/password input and social login
- **Registration Screen**: Dedicated screen for new user sign-ups with email confirmation modal
- **Navigation Flow**: Login → Sign Up link → Registration → Email Confirmation Modal → Auto-navigate to Login
- Both screens support email/password and social authentication (Google, Facebook)
- Password validation enforced (6+ characters, confirmation matching)
- Authentication managed by `AuthService` via Supabase
- **First-time users**: Onboarding screen (3 pages) → Login/Registration

#### Email Confirmation Flow (Multi-Layer Protection)

Users cannot access the app unless their email is confirmed:

1. **Registration Sign-Out**: User is automatically signed out after registration (before email confirmation)
2. **Email Confirmation Modal**: Non-dismissible modal with:
   - Email display in highlighted box
   - Step-by-step instructions ("Check inbox", "Click link", "Account activated", "Redirected to login")
   - Helpful tip: "Check your spam folder if you don't see the email"
   - Loading spinner indicating "Waiting for email confirmation..."
   - Resend Email button
   - **Auto-detection timer**: Checks every 2 seconds if user clicked confirmation link
3. **Success Screen**: Shows when email is confirmed:
   - Celebratory checkmark icon
   - "Email Verified!" message
   - 3-second countdown to redirect
   - Auto-navigates to login screen
4. **Login Protection**: Rejects unconfirmed emails with error: "Please confirm your email before logging in"
5. **App Startup Protection**: `AuthService.initialize()` checks `emailConfirmedAt`:
   - Only logs in users with confirmed emails
   - Signs out users with unconfirmed emails (if they force-close/reopen app)

**Result**: Unconfirmed users cannot:

- ❌ Be added to the users table automatically
- ❌ Login during registration
- ❌ Access app on restart
- ❌ Dismiss confirmation modal

### 5. Customer / Farmer Mode Switching

- Customers see: Home → Community → Profile
- After registering as a farmer, users can switch to Farmer mode
- Farmers see: Dashboard → Community → Profile
- Mode managed by `AuthService.isViewingAsFarmer`

### 6. Onboarding Flow (Mobile)

- **Page 1**: "Direct From Farm" (farm image background, dark overlay)
  - Title: "Direct From Farm"
  - Subtitle: "Connect directly with local farmers for the freshest produce"
  - CTA: Dark navy button
- **Page 2**: "Pre-Order Upcoming Harvests" (harvest image background)
  - Shopping basket icon with countdown timer
  - Title: "Pre-Order Upcoming Harvests"
  - Subtitle: "Secure seasonal favorites"
  - CTA: Dark navy button
- **Page 3**: "AI-Powered Insights" (community image with light white overlay)
  - Sparkle icon with green background
  - Title: "AI-Powered Insights"
  - Subtitle: "Weather alerts, demand predictions, community knowledge"
  - CTA: Green "Get Started" button
- Shown once on first app launch; tracked via `OnboardingService`
- Uses `SharedPreferences` to persist completion state

## Adding New Features

| What              | Where                                      |
| ----------------- | ------------------------------------------ |
| New data model    | `shared/models/my_model.dart`              |
| New service/API   | `shared/services/my_service.dart`          |
| New mobile screen | `mobile/screens/[category]/my_screen.dart` |
| New web screen    | `web/screens/web_my_screen.dart`           |

## AuthService Implementation Details

### Key Methods

- **`initialize()`**: Called on app startup
  - Checks if user exists AND `emailConfirmedAt` is not null
  - Only logs in confirmed users
  - Signs out unconfirmed users (prevents unauthorized access on app restart)
- **`register(name, email, password)`**: User registration
  - Creates user in Supabase Auth (with name metadata)
  - Ensures user profile exists in database (fallback if trigger fails)
  - **Automatically signs out user** before email confirmation
  - Returns `true` on success (triggers confirmation modal in UI)
- **`login(email, password)`**: User login
  - Attempts login with Supabase Auth
  - **Checks if `emailConfirmedAt` exists** (not null = confirmed)
  - Rejects unconfirmed emails with error message
  - Signs out unconfirmed users to prevent session hijacking
  - Only logs in confirmed users

- **`logout()`**: User logout
  - Signs out from Supabase Auth
  - Clears all local user state

### Email Confirmation Flow in UI

**RegistrationScreen** (`mobile/screens/auth/registration_screen.dart`):

1. User fills form → clicks Register
2. `_handleRegister()` validates input → calls `AuthService.register()`
3. If successful → calls `_showEmailConfirmationScreen(email)`
4. Modal displays with:
   - Non-dismissible dialog (PopScope canPop: false)
   - Timer that checks every 2 seconds: `user.emailConfirmedAt != null`
   - If confirmed → shows success screen
5. Success screen counts down 3 seconds → auto-navigates to `/login`
6. User logs in with confirmed email

## Key Dependencies

| Package                       | Purpose                        |
| ----------------------------- | ------------------------------ |
| `supabase_flutter`            | Auth + database                |
| `shared_preferences`          | Local storage (onboarding)     |
| `camera`                      | Live camera preview            |
| `google_mlkit_face_detection` | Auto face detection            |
| `image_picker`                | Gallery/camera photo picking   |
| `google_fonts`                | Typography (Plus Jakarta Sans) |
| `cached_network_image`        | Image caching                  |
| `fl_chart`                    | Dashboard charts               |

## App Configuration

### App Name

- **Display Name**: ArgiDirect
- **Dart Package**: argidirect
- Updated in: `pubspec.yaml`, `android/`, `ios/`, `web/`

### Supabase Backend

- **URL**: `https://ywfppgarzyksacgbesme.supabase.co`
- **Anon Key**: Stored in `supabase_config.dart`
- **Core Tables**: users, farmer_registrations, products, orders, etc.

## Recent Updates (Feb 2026)

1. **Login Screen Redesign**: Modern, clean design with email/password fields, social login (Google, Facebook)
2. **Registration Screen**: New dedicated registration screen with:
   - Full Name, Email, Password, Confirm Password fields
   - Password validation (6+ characters, matching confirmation)
   - Social registration options
   - **Email confirmation modal** (non-dismissible)
   - Navigation back to login after registration
3. **Email Confirmation Workflow** (Complete Implementation):
   - **Confirmation Modal**: Shows email address, step-by-step instructions, helpful tips, and resend button
   - **Auto-Detection Timer**: Checks every 2 seconds if user clicked confirmation email link
   - **Success Screen**: Displays when email confirmed, auto-navigates to login after 3 seconds
   - **Login Rejection**: Unconfirmed emails rejected with clear error message
   - **App Startup Protection**: `AuthService.initialize()` now checks `emailConfirmedAt` property:
     - Only logs in confirmed users
     - Signs out unconfirmed users on app restart
   - **Multi-Layer Enforcement**: Users cannot access app at 3 checkpoints (registration, login, startup)
4. **Navigation Integration**: "Sign Up" button on login screen navigates to registration screen
5. **Onboarding Integration**: 3-page onboarding screen for first-time mobile users
6. **SharedPreferences**: Persistent onboarding state tracking
7. **App Rename**: Rebranded to "ArgiDirect" across all platforms
8. **OnboardingService**: New service layer for onboarding state management
9. **Asset Management**: Proper asset path configuration and pubspec.yaml setup
10. **Image Assets Fixed**: Corrected image paths from `Image.network()` with backslashes to `Image.asset()` with forward slashes
11. **UI Refinements**:
    - Page 3 overlay opacity adjusted (alpha 60 for better color vibrancy)
    - Page 1 button color changed to dark navy (0xFF1A1A2E)
