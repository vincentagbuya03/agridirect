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
│       │   ├── home_screen.dart                 # Consumer home with featured farmers
│       │   ├── marketplace_screen.dart          # Consumer marketplace (products from Supabase)
│       │   ├── preorder_hub_screen.dart         # Pre-order products (from Supabase)
│       │   ├── preorder_product_details.dart    # Product details/pre-order
│       │   ├── community_hub_screen.dart        # Community forum & articles
│       │   ├── orders_screen.dart               # Customer order history
│       │   └── profile_screen.dart              # User profile
│       └── farmer/
│           ├── farmer_sales_dashboard.dart      # Farmer dashboard with metrics
│           ├── farmer_products_screen.dart      # Farmer inventory (from Supabase)
│           ├── farmer_orders_screen.dart        # Farmer orders (from Supabase)
│           ├── farmer_community_hub.dart        # Community/social features
│           └── farmer_settings_screen.dart      # Farmer settings
│
├── web/
│   ├── web_navigation.dart            # Web layout & routing
│   └── screens/
│       ├── web_login_screen.dart           # Web login
│       ├── web_registration_screen.dart    # Web user registration
│       ├── web_farmer_registration_screen.dart  # Web farmer registration
│       ├── web_marketplace_home.dart       # Web marketplace (products from Supabase)
│       ├── web_preorder_details.dart       # Web product details (products from Supabase)
│       ├── web_community_hub.dart          # Web community (posts/articles from Supabase)
│       ├── web_profile_screen.dart         # Web profile
│       └── web_sales_dashboard.dart        # Web dashboard
│
└── shared/
    ├── data/
    │   └── app_data.dart              # Model classes: ProductItem, ForumPostItem, ArticleItem, DashboardMetric
    ├── models/
    │   ├── farmer_registration.dart   # FarmerRegistration data model
    │   └── weather_model.dart         # Weather data models (WeatherData, WeatherForecast)
    ├── services/
    │   ├── auth_service.dart          # Authentication & user state (Supabase Auth)
    │   ├── onboarding_service.dart    # Onboarding tracking (SharedPreferences)
    │   ├── supabase_config.dart       # Supabase init + SupabaseDB operations
    │   ├── supabase_data_service.dart # **NEW** - Cloud data service (products, posts, articles, orders, farmers)
    │   └── weather_service.dart       # Weather API integration (OpenWeatherMap + mock data)
    └── utils/
        └── responsive.dart            # Screen-size breakpoint helpers
```

## Architecture Principles

### 1. Separation by Platform (Mobile vs Web)

- **Mobile** — Bottom navigation, touch-friendly, compact layouts
- **Web** — Sidebar/horizontal navigation, mouse/keyboard optimized, wider layouts
- Each platform has its own screen implementations

### 2. Shared Layer

- **Models**: Data structures for app entities
  - `FarmerRegistration`: Farmer registration data model
  - `WeatherData` / `WeatherForecast`: Weather API responses
- **Services** - Cloud-first architecture:
  - `AuthService`: Manages authentication & user roles via Supabase Auth
  - `OnboardingService`: Tracks onboarding completion via SharedPreferences
  - `SupabaseConfig`: Supabase initialization & authentication
  - **`SupabaseDataService`** (NEW): Main data access layer for all cloud operations
    - **Query Methods**: `getProducts()`, `getPreOrderProducts()`, `getNearbyProducts()`, `getForumPosts()`, `getArticles()`, `getFarmerProducts()`, `getFarmerOrders()`, `getCustomerOrders()`, `getFeaturedFarmers()`, `getDashboardMetrics()`
    - **Features**: Type-safe data mapping from Supabase JSON → Dart models, error handling with fallback data, real-time support
    - **Singleton Pattern**: Single instance across app lifecycle ensures consistent data fetching
  - `WeatherService`: OpenWeatherMap API integration with 5-day forecast & mock fallback data
- **Data**: Model classes (`ProductItem`, `ForumPostItem`, `ArticleItem`, `DashboardMetric`)
- **Utils**: Responsive breakpoints, helper functions

### 2.5. Supabase Cloud Database Architecture

**Core Tables** (PostgreSQL in Supabase):

| Table | Purpose | Key Columns |
| --- | --- | --- |
| `products` | Farm products catalog | name, farm, price, unit, image_url, rating, is_preorder, category, farmer_id |
| `forum_posts` | Community discussion posts | user_id, title, body, image_url, likes, comments, user_name, user_location |
| `articles` | Agricultural knowledge articles | title, content, author, read_time, image_url, excerpt |
| `orders` | Purchase order tracking | order_number, customer_id, farmer_id, items, total, status |
| `farmer_profiles` | Farmer business information | farm_name, specialty, location, distance, rating, badge, tags |
| `post_likes` | Like tracking for forum posts | post_id, user_id |

**Security**:
- **Row Level Security (RLS)**: All tables protected with policies
- Users can only read public products/posts/articles
- Users can only write/edit their own data (posts, orders as customer)
- Farmers can only manage products where `farmer_id = auth.uid()`

**Data Flow**:
1. Screen calls `SupabaseDataService().getXxx()` method
2. Service queries Supabase REST API via `SupabaseConfig.client`
3. Supabase enforces RLS policies at database level
4. Results parsed from JSON → Dart models (type-safe)
5. FutureBuilder displays loading state → data → error
6. Fallback data shown if Supabase temporarily unavailable

### 3. Adaptive Entry Point

- `main.dart` uses `LayoutBuilder` to detect screen width
- Width > 800px → `WebNavigation`
- Width ≤ 800px → `MobileNavigation`
- First-time mobile users see 3-page onboarding before login
- Initialization flow:
  1. Check onboarding status (SharedPreferences)
  2. Initialize Supabase auth session
  3. Check email confirmation status
  4. Route to onboarding → login or main app

### 4. Authentication & Registration (Supabase Auth)

- **Login Screen**: Clean, modern design with email/password input
- **Registration Screen**: Dedicated screen for new user sign-ups with email confirmation modal
- **Navigation Flow**: Login → Sign Up link → Registration → Email Confirmation Modal → Auto-navigate to Login
- **Authentication**: Managed by `AuthService` via Supabase Authentication
- Password validation enforced (6+ characters, confirmation matching)
- **First-time users**: Onboarding screen (3 pages) → Login/Registration
- **User Profiles**: Automatically created in `users` table on successful registration
- **Role Management**: User role (customer/farmer) stored in `auth.user.user_metadata`

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

### 7. Cloud Data Fetching Pattern (SupabaseDataService)

All screens that display dynamic data (products, posts, farmers, orders) follow this pattern:

```dart
Widget _buildProductList() {
  return FutureBuilder<List<ProductItem>>(
    future: SupabaseDataService().getNearbyProducts(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || snapshot.data == null) {
        return const Center(child: Text('No products available'));
      }
      final products = snapshot.data!;
      return ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) => ProductCard(product: products[index]),
      );
    },
  );
}
```

**Key Screens Using This Pattern**:

| Screen | Data Source | Method |
| --- | --- | --- |
| `marketplace_screen.dart` | Supabase products table | `getNearbyProducts()` |
| `preorder_hub_screen.dart` | Supabase products table (is_preorder=true) | `getPreOrderProducts()` |
| `home_screen.dart` | Supabase farmer_profiles table | `getFeaturedFarmers()` |
| `community_hub_screen.dart` | Supabase forum_posts, articles tables | `getForumPosts()`, `getArticles()` |
| `farmer_products_screen.dart` | Supabase products table (farmer_id = current user) | `getFarmerProducts()` |
| `farmer_orders_screen.dart` | Supabase orders table (farmer_id = current user) | `getFarmerOrders()` |
| Web equivalents | Same Supabase queries | Same methods |

**Error Handling**: Service catches exceptions and returns fallback empty lists or default data (e.g., featured farmers have hardcoded fallback)

**Type Safety**: All responses converted from Supabase JSON to strongly-typed Dart models

## Adding New Features

| What | Where | Notes |
| --- | --- | --- |
| New data model | `shared/models/my_model.dart` | Use in SupabaseDataService for type mapping |
| New Supabase table | Run SQL in Supabase SQL Editor | Add query method to SupabaseDataService |
| New query method | `shared/services/supabase_data_service.dart` | Implement type mapping from JSON → Dart model, add error handling |
| New mobile screen | `mobile/screens/[category]/my_screen.dart` | Call SupabaseDataService methods in FutureBuilder |
| New web screen | `web/screens/web_my_screen.dart` | Call SupabaseDataService methods in FutureBuilder |
| New API integration | `shared/services/my_api_service.dart` | Singleton pattern for consistency |

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

| Package | Purpose | Version |
| --- | --- | --- |
| `supabase_flutter` | Cloud auth + database (REST API) | Latest |
| `shared_preferences` | Local storage (onboarding, preferences) | Latest |
| `camera` | Live camera preview | Latest |
| `google_mlkit_face_detection` | Automated face detection | Latest |
| `image_picker` | Gallery/camera photo selection | Latest |
| `google_fonts` | Typography (Plus Jakarta Sans) | Latest |
| `cached_network_image` | Efficient image caching & loading | Latest |
| `fl_chart` | Dashboard charts & analytics | Latest |
| `http` | HTTP requests (weather API, fallback) | Latest |


## App Configuration

### App Name

- **Display Name**: ArgiDirect
- **Dart Package**: argidirect
- Updated in: `pubspec.yaml`, `android/`, `ios/`, `web/`

### Supabase Backend (Cloud Database)

- **URL**: `https://ywfppgarzyksacgbesme.supabase.co`
- **Anon Key**: Stored securely in `supabase_config.dart`
- **Database**: PostgreSQL with REST API access via `supabase_flutter` SDK

**Tables Created** (see `supabase_tables.sql` for complete schema):
- **products**: Catalog of farm produce with pricing & ratings
  - Columns: id, name, farm, price, unit, image_url, rating, reviews, harvest_days, category, is_preorder, farmer_id
  - Indexes: farmer_id, category, is_preorder for fast filtering
- **forum_posts**: Community discussion posts with like tracking
  - Columns: id, user_id, user_name, user_location, title, body, image_url, likes, comments
- **articles**: Educational content about farming & agriculture
  - Columns: id, title, excerpt, content, author, read_time, image_url
- **orders**: Purchase order tracking with status
  - Columns: id, order_number, customer_id, farmer_id, items (JSON), total, status, created_at
- **farmer_profiles**: Business profiles of farmers
  - Columns: id, farm_name, specialty, location, distance, rating, badge, tags
- **post_likes**: Junction table for tracking which users liked which posts
  - Columns: id, post_id, user_id
- **users**: User profiles (auto-created by Auth trigger)
  - Columns: id, email, name, role (customer/farmer), created_at

**Row Level Security**:
- All tables protected with RLS policies
- Users can view public products/posts/articles
- Users can only edit their own posts and orders
- Farmers can only manage products where `farmer_id = auth.uid()`

**Helper Functions**:
- `increment_post_likes()`: Increments post like count
- `decrement_post_likes()`: Decrements post like count

**Seed Data**:
- 10 sample products across categories
- 4 community forum posts
- 4 agricultural articles
- 3 featured farmer profiles

## Recent Updates (Feb 2026)

### Phase 1: Foundation (Early Feb)
1. **Login Screen Redesign**: Modern, clean design with email/password fields
2. **Registration Screen**: New dedicated registration screen with email confirmation modal
3. **Email Confirmation Workflow** (Complete Implementation):
   - Non-dismissible confirmation modal with auto-detection timer
   - Checks every 2 seconds if user clicked confirmation email link
   - Auto-navigates to login after email confirmed
   - App startup checks prevent unconfirmed users from accessing app
4. **Onboarding Integration**: 3-page onboarding screen for first-time mobile users
5. **OnboardingService**: SharedPreferences-based state tracking
6. **App Branding**: Rebranded to "ArgiDirect" across all platforms

### Phase 2: Local Data Management (Mid Feb)
7. **ProductDatabaseService**: SQLite-based local database (sqflite)
8. **DatabaseSeederService**: Automated seeding of products & farmers
9. **Mobile Marketplace**: Integrated FutureBuilder with local SQLite database
10. **Pre-Order Hub**: Dynamic pre-order loading from local database
11. **Web Marketplace**: Migrated from hardcoded to SQLite queries
12. **Error Fixes**: Fixed FutureBuilder structure and compilation errors

### Phase 3: Cloud Migration to Supabase (Late Feb - CURRENT)
13. **SupabaseDataService** (NEW): Comprehensive cloud data service (545 lines)
    - 9+ query methods for all data types
    - Type-safe JSON → Dart model conversion
    - Singleton pattern for consistent access
    - Error handling with fallback data
14. **Supabase Database Schema** (`supabase_tables.sql`):
    - 6 tables: products, forum_posts, articles, orders, farmer_profiles, post_likes
    - Complete RLS security policies
    - 10 sample products, 4 posts, 4 articles, 3 farmers (seed data)
15. **Screen Migrations** (All Updated to Supabase):
    - `marketplace_screen.dart` → `getNearbyProducts()`
    - `preorder_hub_screen.dart` → `getPreOrderProducts()`
    - `home_screen.dart` → `getFeaturedFarmers()`
    - `community_hub_screen.dart` → `getForumPosts()` / `getArticles()`
    - `farmer_products_screen.dart` → `getFarmerProducts()`
    - `farmer_orders_screen.dart` → `getFarmerOrders()`
    - All web equivalents updated
16. **Code Cleanup**: Removed 15+ references to old SQLite service
17. **Compilation Status**: ✅ **0 errors** - All screens compile successfully
