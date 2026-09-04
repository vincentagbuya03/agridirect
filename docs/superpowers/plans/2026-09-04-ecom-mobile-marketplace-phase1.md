# AgriDirect Mobile Marketplace (Shopee/Lazada Style) Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the AgriDirect mobile consumer landing experience into a high-density, modular Shopee/Lazada-style e-commerce marketplace powered exclusively by real Supabase data with zero mock/garbage items.

**Architecture:** Decompose the 2,000+ line monolithic `home_screen.dart` into a modular suite of reactive widgets under `lib/mobile/screens/consumer/home/widgets/`. Coordinate them inside a high-performance `CustomScrollView` with sliver scroll physics, real-time cart/notification badges, live flash sale countdown tickers, and a 2-column discovery product feed.

**Tech Stack:** Flutter / Dart, Supabase Flutter SDK, Provider / ValueNotifier / StreamBuilder, CachedNetworkImage, GoogleFonts.

## Global Constraints

- **Strict Real-Data Guarantee (Zero Garbage / Mock Data):** Absolutely no dummy/mock crops or synthetic stats. All items, prices, categories, and farms are fetched live from Supabase (`v_products`, `categories`, `farmer_profiles`, `user_vouchers`).
- **Conditional Metric Rendering:**
  - Discount tags (`-XX%`) only render if `discountPercent > 0` and `originalPrice != null`.
  - Sold volume counters only render if real orders exist (`soldCount != null && soldCount > 0`).
  - Flash Sale section collapses to `SizedBox.shrink()` if no active flash sales exist in Supabase.
  - Proximity distance only computes if user and farmer coordinates are valid.
- **Brand Aesthetic:** AgriDirect Emerald Green (`#16A34A` / `#2E7D32`) brand core + Shopee Flame Orange (`#FF5722`) accents exclusively for flash sales, discount tags, and countdown clocks.

---

### Task 1: Shopee-Style E-Commerce Product Card (`EcomProductCard`)

**Files:**
- Create: `lib/mobile/screens/consumer/home/widgets/ecom_product_card.dart`
- Create: `test/widgets/ecom_product_card_test.dart`

**Interfaces:**
- Consumes: `ProductItem` from `lib/shared/data/app_data.dart`, `CartService` from `lib/shared/services/commerce/cart_service.dart`
- Produces: `EcomProductCard` widget accepting `product`, optional `userPosition`, and callbacks `onTap`, `onAddToCart`

- [ ] **Step 1: Write widget test for `EcomProductCard`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/mobile/screens/consumer/home/widgets/ecom_product_card.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('EcomProductCard renders product info and conditional discount badge', (tester) async {
    const productWithDiscount = ProductItem(
      productId: 'p-1',
      name: 'Benguet Highland Cabbage',
      farm: 'Mountain Greens Farm',
      price: '80',
      originalPrice: '100',
      discountPercent: 20,
      unit: 'kg',
      imageUrl: '',
      soldCount: 45,
      rating: '4.8',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcomProductCard(product: productWithDiscount),
        ),
      ),
    );

    expect(find.text('Benguet Highland Cabbage'), findsOneWidget);
    expect(find.text('Mountain Greens Farm'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget);
    expect(find.text('45 sold'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/ecom_product_card_test.dart`  
Expected: Compilation failure or missing `ecom_product_card.dart`.

- [ ] **Step 3: Implement `EcomProductCard`**

Create `lib/mobile/screens/consumer/home/widgets/ecom_product_card.dart` with:
- 1:1 Aspect ratio image container with fallback `Icons.agriculture_rounded`.
- Top-left discount badge (rendered only if `discountPercent != null && discountPercent > 0`).
- Farm verified badge (`🌱 [farm]`).
- Product title (max 2 lines with ellipsis).
- Dual pricing: Bold primary price + strikethrough original price if discount applies.
- Social proof: Rating (`★ 4.8`) and Sold count (only if `soldCount != null && soldCount > 0`).
- Proximity tag (computed from distance if user position is supplied).
- "+ Cart" button with inkwell tap dispatching `CartService().addToCart()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/ecom_product_card_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mobile/screens/consumer/home/widgets/ecom_product_card.dart test/widgets/ecom_product_card_test.dart
git commit -m "feat: implement Shopee-style EcomProductCard with real-data conditional rendering"
```

---

### Task 2: Live Flash Deals Section with Countdown Ticker (`EcomFlashSaleSection`)

**Files:**
- Create: `lib/mobile/screens/consumer/home/widgets/ecom_flash_sale_section.dart`
- Create: `test/widgets/ecom_flash_sale_test.dart`

**Interfaces:**
- Consumes: `List<ProductItem> flashProducts` from `SupabaseDataService().getFlashSaleProducts()`
- Produces: `EcomFlashSaleSection` widget displaying countdown ticker and horizontal product scroll; returns `SizedBox.shrink()` if `flashProducts.isEmpty`

- [ ] **Step 1: Write widget test for `EcomFlashSaleSection`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/mobile/screens/consumer/home/widgets/ecom_flash_sale_section.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('EcomFlashSaleSection collapses when products list is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcomFlashSaleSection(flashProducts: []),
        ),
      ),
    );

    expect(find.text('FLASH DEALS'), findsNothing);
  });

  testWidgets('EcomFlashSaleSection renders header and deals when products present', (tester) async {
    final products = [
      ProductItem(
        productId: 'f-1',
        name: 'Organic Red Tomatoes',
        farm: 'Valley Farm',
        price: '40',
        originalPrice: '60',
        discountPercent: 33,
        unit: 'kg',
        imageUrl: '',
        isFlashSale: true,
        flashSaleEnd: DateTime.now().add(const Duration(hours: 3)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EcomFlashSaleSection(flashProducts: products),
        ),
      ),
    );

    expect(find.text('FLASH DEALS'), findsOneWidget);
    expect(find.text('Organic Red Tomatoes'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/ecom_flash_sale_test.dart`  
Expected: FAIL.

- [ ] **Step 3: Implement `EcomFlashSaleSection`**

Create `lib/mobile/screens/consumer/home/widgets/ecom_flash_sale_section.dart` with:
- If `flashProducts.isEmpty`, return `const SizedBox.shrink()`.
- Flame orange gradient header with `⚡ FLASH DEALS` and countdown timer `[HH] : [MM] : [SS]`.
- Countdown calculates remaining duration against earliest `flashSaleEnd` using a 1-second `Timer`.
- Horizontal scroll of compact flash deal cards with discount ribbon, price, and real stock claim indicator bar.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/ecom_flash_sale_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/mobile/screens/consumer/home/widgets/ecom_flash_sale_section.dart test/widgets/ecom_flash_sale_test.dart
git commit -m "feat: implement EcomFlashSaleSection with live countdown ticker"
```

---

### Task 3: Dynamic Category Matrix Grid (`EcomCategoryGrid`)

**Files:**
- Create: `lib/mobile/screens/consumer/home/widgets/ecom_category_grid.dart`

**Interfaces:**
- Consumes: `Future<List<CategoryItem>> getCategories()` from `SupabaseDataService()`
- Produces: `EcomCategoryGrid` widget with 2-row horizontally scrolling category squircles and icon resolver

- [ ] **Step 1: Implement `EcomCategoryGrid`**

Create `lib/mobile/screens/consumer/home/widgets/ecom_category_grid.dart`:
- Fetches real categories from `SupabaseDataService().getCategories()`.
- Renders a 2-row horizontal scroll view with circular squircle icons.
- Resolves appropriate Icons dynamically based on category name (e.g. `Vegetables` -> `Icons.eco_rounded`, `Fruits` -> `Icons.apple_rounded`, `Grains` -> `Icons.grain_rounded`, `Poultry` -> `Icons.egg_alt_rounded`, `Fish` -> `Icons.set_meal_rounded`).
- On tap, calls `onCategorySelected(category)`.

- [ ] **Step 2: Verify compilation via `flutter analyze`**

Run: `flutter analyze lib/mobile/screens/consumer/home/widgets/ecom_category_grid.dart`  
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/mobile/screens/consumer/home/widgets/ecom_category_grid.dart
git commit -m "feat: implement dynamic 2-row EcomCategoryGrid with database category binding"
```

---

### Task 4: Auto-Sliding Hero Promotional Banner (`EcomHeroBanner`)

**Files:**
- Create: `lib/mobile/screens/consumer/home/widgets/ecom_hero_banner.dart`

**Interfaces:**
- Consumes: Banner image list / promotion data
- Produces: `EcomHeroBanner` widget with 16:9 ratio, 4s auto-play interval, and bottom-right floating pill indicator (`1 / N`)

- [ ] **Step 1: Implement `EcomHeroBanner`**

Create `lib/mobile/screens/consumer/home/widgets/ecom_hero_banner.dart`:
- `PageView.builder` with 16:9 aspect ratio and rounded card margins.
- Auto-scroll timer on a 4-second period, pausing when user is dragging.
- Floating bottom-right indicator pill showing `"${currentPage + 1} / ${totalPages}"`.

- [ ] **Step 2: Verify compilation via `flutter analyze`**

Run: `flutter analyze lib/mobile/screens/consumer/home/widgets/ecom_hero_banner.dart`  
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/mobile/screens/consumer/home/widgets/ecom_hero_banner.dart
git commit -m "feat: implement 16:9 auto-sliding EcomHeroBanner carousel"
```

---

### Task 5: Sticky E-Commerce Sliver Header (`EcomSliverAppBar`)

**Files:**
- Create: `lib/mobile/screens/consumer/home/widgets/ecom_sliver_app_bar.dart`

**Interfaces:**
- Consumes: `UserService` (delivery address), `CartService` (cart item count), `NotificationService` (unread count)
- Produces: `EcomSliverAppBar` extending `SliverAppBar` with sticky collapsible search bar, QR scanner, location pill, and real-time badged action icons

- [ ] **Step 1: Implement `EcomSliverAppBar`**

Create `lib/mobile/screens/consumer/home/widgets/ecom_sliver_app_bar.dart`:
- Top location strip: `📍 Deliver to [Address] ▾` tapping to switch address.
- Rounded search field with animated hint texts and inside camera/QR icon.
- Action icons:
  - Notification icon with unread badge connected to `NotificationService().unreadCountNotifier`.
  - Cart icon with reactive badge counter connected to `CartService().totalCartItemsNotifier`.
- Collapsible pinned `SliverAppBar` behavior with smooth emerald-to-white surface transition.

- [ ] **Step 2: Verify compilation via `flutter analyze`**

Run: `flutter analyze lib/mobile/screens/consumer/home/widgets/ecom_sliver_app_bar.dart`  
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/mobile/screens/consumer/home/widgets/ecom_sliver_app_bar.dart
git commit -m "feat: implement Shopee-style sticky EcomSliverAppBar with live badges"
```

---

### Task 6: HomeScreen Modular Assembly & CustomScrollView Integration

**Files:**
- Modify: `lib/mobile/screens/consumer/home_screen.dart`

**Interfaces:**
- Consumes: All 5 widgets created in Tasks 1-5, `SupabaseDataService`, `CartService`, `UserService`
- Produces: Full Shopee/Lazada style Consumer Home Screen using `CustomScrollView`

- [ ] **Step 1: Assemble `HomeScreen` with Slivers**

Refactor `lib/mobile/screens/consumer/home_screen.dart`:
- Replace deeply nested column with a `RefreshIndicator` wrapping `CustomScrollView`.
- Slivers hierarchy:
  1. `EcomSliverAppBar`
  2. `SliverToBoxAdapter` -> `EcomHeroBanner`
  3. `SliverToBoxAdapter` -> `EcomCategoryGrid`
  4. `SliverToBoxAdapter` -> `EcomFlashSaleSection`
  5. `SliverPersistentHeader` -> Sticky section title: `"DAILY DISCOVERIES"`
  6. `SliverPadding` -> `SliverGrid` rendering 2 columns of `EcomProductCard`
- Keep existing listeners, pull-to-refresh parallel futures, and offline caching intact.

- [ ] **Step 2: Verify compilation and tests**

Run: `flutter test` and `flutter analyze`  
Expected: All tests pass, 0 analysis errors.

- [ ] **Step 3: Commit**

```bash
git add lib/mobile/screens/consumer/home_screen.dart
git commit -m "feat: modernize consumer HomeScreen with modular sliver e-commerce architecture"
```

---

### Task 7: End-to-End Verification & Walkthrough

- [ ] **Step 1: Run full automated test suite**

Run: `flutter test`  
Expected: All tests pass.

- [ ] **Step 2: Run Flutter static analysis across the entire project**

Run: `flutter analyze lib/mobile/screens/consumer/`  
Expected: 0 errors, clean code.

- [ ] **Step 3: Commit all changes and document walkthrough**

```bash
git commit -m "chore: complete mobile e-commerce marketplace phase 1 modernization"
```
