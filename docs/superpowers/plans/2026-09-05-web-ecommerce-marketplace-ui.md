# Web E-Commerce & Marketplace UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the AgriDirect Flutter Web interface into a premier agricultural e-commerce marketplace with a component-driven architecture, 3-tier omnibar header, dynamic hero bento grid, faceted shop filters, rich farm trust profiles, and multi-farm grouped cart.

**Architecture:** Establish a dedicated, reusable e-commerce component library in `lib/web/widgets/ecom/` driven by centralized tokens in `WebDesignTokens`. Refactor core consumer screens (`web_marketplace_home.dart`, `web_shop_screen.dart`, `web_product_details.dart`, `web_cart_screen.dart`, `web_cart_checkout_screen.dart`) from monolithic layouts into modular, responsive assemblies supporting desktop extra-wide (≥1440px), desktop (1024px–1439px), tablet (768px–1023px), and mobile web (<768px).

**Tech Stack:** Flutter Web, Dart 3.x, `google_fonts` (Rubik & Nunito Sans), `go_router`, `supabase_flutter`, `cached_network_image`.

## Global Constraints

- Platform: Flutter Web responsive down to mobile viewports.
- Color Standards: Primary Emerald (`0xFF16A34A`), Dark Slate (`0xFF0F172A`), Background Canvas (`0xFFF8FAFC`), Surface White (`0xFFFFFFFF`), Deal Amber (`0xFFEA580C`), Trust Blue (`0xFF2563EB`).
- Typography: `GoogleFonts.rubik()` for headings, prices, and badges; `GoogleFonts.nunitoSans()` for body, descriptions, and filters.
- Data Contract: Seamlessly bind with `ProductItem`, `FarmerProfile`, `ProductReview`, `CartService`, and `SupabaseDataService`.
- No regression: All existing routes, cart state listeners, and auth checks must remain intact.

---

### Task 1: Design Tokens & Foundational Theme System

**Files:**
- Create: `lib/web/constants/web_design_tokens.dart`
- Test: `test/widgets/web_design_tokens_test.dart`

**Interfaces:**
- Produces: `WebDesignTokens` class containing static color constants, `GoogleFonts` text styles (`h1`, `h2`, `h3`, `priceLarge`, `priceMedium`, `bodyRegular`, `caption`), elevation shadows (`cardRest`, `cardHover`), and responsive layout breakpoint helper `WebBreakpoints` (`isDesktopWide`, `isDesktop`, `isTablet`, `isMobile`).

- [ ] **Step 1: Write the failing unit/widget test for WebDesignTokens**

```dart
// test/widgets/web_design_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/constants/web_design_tokens.dart';

void main() {
  test('WebDesignTokens defines expected brand colors and text styles', () {
    expect(WebDesignTokens.primary, const Color(0xFF16A34A));
    expect(WebDesignTokens.dark, const Color(0xFF0F172A));
    expect(WebDesignTokens.bg, const Color(0xFFF8FAFC));
    expect(WebDesignTokens.dealAmber, const Color(0xFFEA580C));
    expect(WebDesignTokens.trustBlue, const Color(0xFF2563EB));
  });

  test('WebBreakpoints correctly evaluates screen widths', () {
    expect(WebBreakpoints.isDesktopWide(1440), isTrue);
    expect(WebBreakpoints.isDesktopWide(1200), isFalse);
    expect(WebBreakpoints.isDesktop(1200), isTrue);
    expect(WebBreakpoints.isTablet(900), isTrue);
    expect(WebBreakpoints.isMobile(600), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/web_design_tokens_test.dart`
Expected: FAIL with compilation error (file not found or identifiers not defined).

- [ ] **Step 3: Implement WebDesignTokens and WebBreakpoints**

```dart
// lib/web/constants/web_design_tokens.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebDesignTokens {
  // Brand Colors
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF14532D);
  static const Color primaryLight = Color(0xFFF0FDF4);
  
  // Neutrals
  static const Color dark = Color(0xFF0F172A);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  // Accents & Signals
  static const Color dealAmber = Color(0xFFEA580C);
  static const Color discountRed = Color(0xFFDC2626);
  static const Color trustBlue = Color(0xFF2563EB);
  static const Color organicGreen = Color(0xFF059669);

  // Box Shadows
  static final List<BoxShadow> cardRest = [
    BoxShadow(
      color: dark.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> cardHover = [
    BoxShadow(
      color: dark.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> dropdownShadow = [
    BoxShadow(
      color: dark.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  // Typography
  static TextStyle h1({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  static TextStyle h2({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.25,
      );

  static TextStyle h3({Color color = dark}) => GoogleFonts.rubik(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      );

  static TextStyle priceLarge({Color color = primary}) => GoogleFonts.rubik(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle priceMedium({Color color = primary}) => GoogleFonts.rubik(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle bodyRegular({Color color = slate700}) =>
      GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color color = dark}) => GoogleFonts.nunitoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle caption({Color color = slate500}) => GoogleFonts.nunitoSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle badge({Color color = Colors.white}) => GoogleFonts.rubik(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      );
}

class WebBreakpoints {
  static const double desktopWide = 1440;
  static const double desktop = 1024;
  static const double tablet = 768;

  static bool isDesktopWide(double width) => width >= desktopWide;
  static bool isDesktop(double width) => width >= desktop && width < desktopWide;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isMobile(double width) => width < tablet;

  static double containerWidth(double screenWidth) {
    if (screenWidth >= 1440) return 1360;
    if (screenWidth >= 1024) return 1100;
    return screenWidth;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_design_tokens_test.dart`
Expected: PASS with 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/web/constants/web_design_tokens.dart test/widgets/web_design_tokens_test.dart
git commit -m "feat(web): establish WebDesignTokens and WebBreakpoints"
```

---

### Task 2: 3-Tier Global Navigation & Omnibar Header System

**Files:**
- Create: `lib/web/widgets/ecom/web_cart_flyout.dart`
- Create: `lib/web/widgets/ecom/web_location_modal.dart`
- Create: `lib/web/widgets/ecom/web_ecom_header.dart`
- Test: `test/widgets/web_ecom_header_test.dart`

**Interfaces:**
- Consumes: `WebDesignTokens`, `CartService`, `AuthService`, `BrandLogo`.
- Produces: `WebEcomHeader` widget with sticky behavior, tier-1 utility bar with barangay selector, tier-2 search omnibar with autocomplete and hover cart flyout, tier-3 department mega-menu.

- [ ] **Step 1: Write widget test for WebEcomHeader**

```dart
// test/widgets/web_ecom_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_ecom_header.dart';

void main() {
  testWidgets('WebEcomHeader renders utility strip, search bar, and department tabs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebEcomHeader(
            currentIndex: 0,
            onNavigate: (index, [route]) {},
          ),
        ),
      ),
    );

    expect(find.byType(WebEcomHeader), findsOneWidget);
    expect(find.textContaining('San Carlos City'), findsWidgets);
    expect(find.byIcon(Icons.search), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/web_ecom_header_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement WebLocationModal, WebCartFlyout, and WebEcomHeader**

Build `lib/web/widgets/ecom/web_location_modal.dart`:
- Barangay selection dialog for San Carlos City (Roxas, Baleyadaan, Tarece, Malabago, etc.) allowing users to set delivery location and recalculate distances.

Build `lib/web/widgets/ecom/web_cart_flyout.dart`:
- Hover/tap flyout overlay showing top 3 items in `CartService.instance.cartItems`, subtotal, and "View Cart" + "Instant Checkout" buttons.

Build `lib/web/widgets/ecom/web_ecom_header.dart`:
- Tier 1: Delivery location pill + farm direct ticker + portal links.
- Tier 2: Brand logo, category dropdown, omnibar text field with real-time crop/farmer suggestion popup, chat icon with unread badge, notification bell, cart button with flyout anchor, and user profile avatar menu.
- Tier 3: Category tabs (`Fresh Vegetables`, `Fruits`, `Grains & Rice`, `Organic & Herbs`, `Flash Deals`, `Pre-Orders`, `Direct Farmers`, `Vouchers`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_ecom_header_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_cart_flyout.dart lib/web/widgets/ecom/web_location_modal.dart lib/web/widgets/ecom/web_ecom_header.dart test/widgets/web_ecom_header_test.dart
git commit -m "feat(web): implement 3-tier WebEcomHeader with Omnibar and Cart Flyout"
```

---

### Task 3: Modern E-Commerce Product Card & Quick View Modal

**Files:**
- Create: `lib/web/widgets/ecom/web_product_card.dart`
- Create: `lib/web/widgets/ecom/web_product_quick_view_dialog.dart`
- Test: `test/widgets/web_product_card_test.dart`

**Interfaces:**
- Consumes: `ProductItem`, `WebDesignTokens`, `CartService`.
- Produces: `WebProductCard` with hover zoom, origin badge, bulk discount pill, rating/sold counts, floating quick-add and quick-view buttons; and `WebProductQuickViewDialog` modal.

- [ ] **Step 1: Write test for WebProductCard**

```dart
// test/widgets/web_product_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_product_card.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('WebProductCard renders title, price, origin, and responds to hover',
      (tester) async {
    final sampleProduct = ProductItem(
      id: 'prod-1',
      title: 'Fresh Native Tomatoes',
      price: 45.0,
      originalPrice: 60.0,
      category: 'Vegetables',
      imageUrl: 'https://example.com/tomato.jpg',
      farmerName: 'Mang Juan',
      farmerLocation: 'Brgy. Roxas',
      rating: 4.9,
      reviewCount: 42,
      soldCount: 150,
      stockQuantity: 25,
      unit: 'kg',
      isOrganic: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebProductCard(
            product: sampleProduct,
            onTap: () {},
            onAddToCart: () {},
          ),
        ),
      ),
    );

    expect(find.text('Fresh Native Tomatoes'), findsOneWidget);
    expect(find.textContaining('₱45'), findsOneWidget);
    expect(find.textContaining('Brgy. Roxas'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/web_product_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement WebProductCard and WebProductQuickViewDialog**

Build `lib/web/widgets/ecom/web_product_card.dart`:
- Aspect ratio 1:1 image with `CachedNetworkImage` or asset fallback.
- `AnimatedScale` on hover (`1.05x`) with smooth elevation shift.
- Origin chip (`📍 Brgy. Roxas`), Organic badge (`🌿 Organic`).
- Strikethrough original price + percentage discount tag (`-25%`).
- Hover overlay action bar: Quick View eye icon + floating emerald "Add to Cart" button.

Build `lib/web/widgets/ecom/web_product_quick_view_dialog.dart`:
- High-res image, farmer name, wholesale tier table preview, stepper quantity, and 1-click add to cart.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_product_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_product_card.dart lib/web/widgets/ecom/web_product_quick_view_dialog.dart test/widgets/web_product_card_test.dart
git commit -m "feat(web): implement WebProductCard with hover micro-interactions and Quick View modal"
```

---

### Task 4: Marketplace Home Storefront Transformation

**Files:**
- Create: `lib/web/widgets/ecom/web_hero_bento_grid.dart`
- Create: `lib/web/widgets/ecom/web_trust_badge_strip.dart`
- Create: `lib/web/widgets/ecom/web_flash_sale_strip.dart`
- Create: `lib/web/widgets/ecom/web_farmer_spotlight_card.dart`
- Modify: `lib/web/screens/consumer/web_marketplace_home.dart`
- Test: `test/widgets/web_marketplace_home_test.dart`

**Interfaces:**
- Consumes: `WebDesignTokens`, `WebEcomHeader`, `WebProductCard`, `WebHeroBentoGrid`, `WebTrustBadgeStrip`, `WebFlashSaleStrip`.
- Produces: Complete storefront landing page with bento hero, live countdown flash deal ticker, visual category slider, cooperative spotlights, and curated product grid.

- [ ] **Step 1: Write integration test for WebMarketplaceHome**

```dart
// test/widgets/web_marketplace_home_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/screens/consumer/web_marketplace_home.dart';

void main() {
  testWidgets('WebMarketplaceHome builds with modern bento and flash deals',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebMarketplaceHome(
          currentIndex: 0,
          onNavigate: (index, [route]) {},
        ),
      ),
    );

    expect(find.byType(WebMarketplaceHome), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify failure or current state**

Run: `flutter test test/widgets/web_marketplace_home_test.dart`

- [ ] **Step 3: Implement components and refactor WebMarketplaceHome**

- `web_hero_bento_grid.dart`: 8-column hero slider with promotional banners + 4-column side cards (Flash Deal spotlight & Farmer spotlight).
- `web_trust_badge_strip.dart`: 4 responsive value pillars (100% Farm-Direct, Same-Day Logistics, Verified Growers, Escrow/COD).
- `web_flash_sale_strip.dart`: Flame header, live countdown timer, claimed percentage bar, and deals carousel.
- `web_farmer_spotlight_card.dart`: Cooperative showcase with portrait, location, trust rating, top 3 produce thumbnails, and visit CTA.
- Refactor `web_marketplace_home.dart`: Replace monolithic layout with the modular components inside a centered `WebBreakpoints.containerWidth` container, wrapping with `WebEcomHeader`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_marketplace_home_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_hero_bento_grid.dart lib/web/widgets/ecom/web_trust_badge_strip.dart lib/web/widgets/ecom/web_flash_sale_strip.dart lib/web/widgets/ecom/web_farmer_spotlight_card.dart lib/web/screens/consumer/web_marketplace_home.dart test/widgets/web_marketplace_home_test.dart
git commit -m "feat(web): overhaul WebMarketplaceHome with hero bento grid and flash sale strip"
```

---

### Task 5: Shop Catalog & Faceted Filter Experience

**Files:**
- Create: `lib/web/widgets/ecom/web_filter_sidebar.dart`
- Modify: `lib/web/screens/consumer/web_shop_screen.dart`
- Test: `test/widgets/web_shop_screen_test.dart`

**Interfaces:**
- Consumes: `WebDesignTokens`, `WebEcomHeader`, `WebProductCard`, `SupabaseDataService`.
- Produces: Faceted filter sidebar (barangay checkboxes, harvest freshness, GAP/Organic certification, dual price slider), density switcher (3/4/5 columns), sort toolbar, active filter pills, and product catalog grid.

- [ ] **Step 1: Write test for WebFilterSidebar and WebShopScreen**

```dart
// test/widgets/web_shop_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/screens/consumer/web_shop_screen.dart';

void main() {
  testWidgets('WebShopScreen renders filter sidebar and product catalog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WebShopScreen(
          currentIndex: 1,
          onNavigate: (index) {},
        ),
      ),
    );

    expect(find.byType(WebShopScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify failure or current state**

Run: `flutter test test/widgets/web_shop_screen_test.dart`

- [ ] **Step 3: Implement WebFilterSidebar and refactor WebShopScreen**

- `web_filter_sidebar.dart`: Sticky sidebar with collapsible sections:
  1. Barangay Location checklist with search box.
  2. Harvest Freshness radio options (<24h, <48h, Pre-Order).
  3. Farming Method checkboxes (Organic, GAP, Hydroponic).
  4. Price range slider + Min/Max text fields.
  5. Farmer rating and deal filters.
- Refactor `web_shop_screen.dart`:
  - Integrate `WebEcomHeader`.
  - Add active filter pill strip with "Clear All" button.
  - Implement 3/4/5 column density toggle and list view switcher.
  - Bind filters to `SupabaseDataService` query with 300ms debounce.
  - Replace product cards with `WebProductCard`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_shop_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_filter_sidebar.dart lib/web/screens/consumer/web_shop_screen.dart test/widgets/web_shop_screen_test.dart
git commit -m "feat(web): modernize WebShopScreen with faceted filter sidebar and catalog toolbar"
```

---

### Task 6: Product Details Screen & Official Farm Storefront Card

**Files:**
- Create: `lib/web/widgets/ecom/web_farm_storefront_card.dart`
- Modify: `lib/web/screens/consumer/web_product_details.dart`
- Test: `test/widgets/web_product_details_test.dart`

**Interfaces:**
- Consumes: `WebDesignTokens`, `WebEcomHeader`, `ProductItem`, `FarmerProfile`, `CartService`.
- Produces: 50/50 two-column desktop product page, image viewer with thumbnail strip and hover zoom, wholesale bulk tier card, harvest timeline, `WebFarmStorefrontCard` with chat and store visit actions, tabbed reviews with customer photos.

- [ ] **Step 1: Write test for WebFarmStorefrontCard and WebProductDetails**

```dart
// test/widgets/web_product_details_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_farm_storefront_card.dart';

void main() {
  testWidgets('WebFarmStorefrontCard renders farmer metrics and action buttons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebFarmStorefrontCard(
            farmerName: 'Mang Juan Dizon',
            farmName: 'San Carlos Organic Growers',
            barangay: 'Brgy. Roxas',
            rating: 4.9,
            responseRate: '98%',
            soldKg: '3,450 kg',
            onChat: () {},
            onVisitStore: () {},
          ),
        ),
      ),
    );

    expect(find.text('Mang Juan Dizon'), findsOneWidget);
    expect(find.textContaining('San Carlos Organic Growers'), findsOneWidget);
    expect(find.textContaining('98%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/web_product_details_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement WebFarmStorefrontCard and refactor WebProductDetails**

- `web_farm_storefront_card.dart`: Verified farmer card showing portrait, cooperative, response rate, total sales, and Chat/Storefront action buttons.
- Refactor `web_product_details.dart`:
  - 50/50 desktop split: Left sticky image gallery with thumbnail carousel; Right purchase engine.
  - Wholesale tier pricing table (1-9 kg, 10-49 kg, 50+ kg).
  - Illustrated harvest timeline (Planted -> Harvested -> Ready).
  - Barangay delivery estimator.
  - Embedded `WebFarmStorefrontCard`.
  - Tabbed specifications, reviews with photo attachments, and "More from this Farmer" carousel.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_product_details_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_farm_storefront_card.dart lib/web/screens/consumer/web_product_details.dart test/widgets/web_product_details_test.dart
git commit -m "feat(web): revamp WebProductDetails with 50/50 layout and WebFarmStorefrontCard"
```

---

### Task 7: Multi-Farm Grouped Cart & Modern Checkout Experience

**Files:**
- Create: `lib/web/widgets/ecom/web_multi_farm_cart_group.dart`
- Modify: `lib/web/screens/consumer/web_cart_screen.dart`
- Modify: `lib/web/screens/consumer/web_cart_checkout_screen.dart`
- Test: `test/widgets/web_cart_test.dart`

**Interfaces:**
- Consumes: `CartService`, `WebDesignTokens`, `WebEcomHeader`.
- Produces: Partitioned cart grouped by farmer/storefront, per-farm voucher strips and fulfillment toggles, sticky order calculation summary, and streamlined 3-step checkout.

- [ ] **Step 1: Write test for WebMultiFarmCartGroup**

```dart
// test/widgets/web_cart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_multi_farm_cart_group.dart';
import 'package:agridirect/shared/services/commerce/cart_service.dart';

void main() {
  testWidgets('WebMultiFarmCartGroup renders farm header and item rows',
      (tester) async {
    final items = [
      CartItem(
        id: 'cart-1',
        title: 'Native Tomatoes',
        price: 45.0,
        quantity: 2,
        imageUrl: '',
        farmerId: 'f1',
        farmerName: 'Mang Juan',
        unit: 'kg',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebMultiFarmCartGroup(
            farmerName: 'Mang Juan',
            items: items,
            isSelected: true,
            onSelectAll: (val) {},
            onQuantityChanged: (item, qty) {},
            onItemRemoved: (item) {},
          ),
        ),
      ),
    );

    expect(find.text('Mang Juan'), findsOneWidget);
    expect(find.text('Native Tomatoes'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/web_cart_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement WebMultiFarmCartGroup and refactor WebCartScreen & WebCartCheckoutScreen**

- `web_multi_farm_cart_group.dart`: Group card partitioning items by farmer, select-all checkbox, per-farm voucher strip, item stepper, fulfillment method toggle.
- Refactor `web_cart_screen.dart`: Multi-farm grouping using `CartService.instance.cartItems`, sticky order calculation summary card with promo code input, checkout CTA.
- Refactor `web_cart_checkout_screen.dart`: 3-step breadcrumb (Address -> Payment/Logistics -> Confirmation) with clean 2-column desktop layout.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/web_cart_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/web/widgets/ecom/web_multi_farm_cart_group.dart lib/web/screens/consumer/web_cart_screen.dart lib/web/screens/consumer/web_cart_checkout_screen.dart test/widgets/web_cart_test.dart
git commit -m "feat(web): implement multi-farm cart grouping and streamlined web checkout"
```

---

### Task 8: End-to-End Responsive Audit & Static Analysis

**Files:**
- Modify: `lib/web/web_navigation.dart` (ensure clean route passing and navbar consistency)
- Verify all web screens

- [ ] **Step 1: Run flutter analyze across entire workspace**

Run: `flutter analyze`
Expected: Zero issues found.

- [ ] **Step 2: Run all widget and e-commerce tests**

Run: `flutter test test/widgets/`
Expected: All tests pass.

- [ ] **Step 3: Commit final integration**

```bash
git commit -m "chore(web): complete e-commerce UI responsive audit and route verification"
```
