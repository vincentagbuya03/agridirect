# AgriDirect Mobile Marketplace (Shopee/Lazada Style) Design Specification

**Date:** 2026-09-04  
**Status:** Approved  
**Scope:** Phase 1: Consumer Home Screen & Discovery Feed Modernization  

---

## 1. Executive Summary
AgriDirect connects local farmers directly with consumers and institutional buyers. While core functionality (authentication, cart, orders, farm profiles) exists, the visual presentation and discovery experience need modernization to match top-tier e-commerce marketplaces like Shopee and Lazada.

This design specification details Phase 1 of the mobile transformation: modularizing and redesigning the Consumer Home Screen and Discovery Feed into a high-density, interactive, and visually captivating agricultural marketplace.

---

## 2. Visual & Brand Design System

### 2.1 Color Palette
- **Brand Core:** AgriDirect Emerald Green (`#16A34A` / `#2E7D32`) for trust, agricultural heritage, and farm-verified badges.
- **Urgency & E-Commerce Accent:** Shopee-inspired Flame Orange / Coral (`#FF5722` / `#FA541C`) used exclusively for:
  - Flash Sale banners and countdown clocks
  - Discount percentage ribbons (`-35%`)
  - "Claim" buttons and progress meters (`🔥 85% claimed`)
- **Backgrounds & Surfaces:** Clean neutral off-white surface (`#F8F9FA` / `#F5F5F5`) with crisp white card containers (`#FFFFFF`), subtle borders (`rgba(0,0,0,0.06)`), and 8-12px rounded elevations.

### 2.2 Typography & Density
- High-density information layout (Shopee standard) with clear optical hierarchy:
  - **Headings:** Bold modern sans-serif (Inter / Outfit)
  - **Prices:** Large bold primary green currency symbols (`₱120`) paired with muted strikethrough original prices (`₱150`)
  - **Micro-Copy:** Compact badges for ratings (`★ 4.9`), unit counts (`1.2k sold`), and distance tags (`📍 3.2km`)

---

## 3. Architecture & Modular Component Decomposition

To replace the 2,000+ line monolithic `home_screen.dart`, the screen will be refactored into focused modular components located under `lib/mobile/screens/consumer/home/`:

```
lib/mobile/screens/consumer/home/
├── widgets/
│   ├── ecom_sliver_app_bar.dart          # Sticky header with location pill, search bar, QR, cart badge
│   ├── ecom_hero_banner.dart             # Auto-sliding 16:9 banner carousel with page pill indicator
│   ├── ecom_category_grid.dart           # 2-row category grid with micro-badges ("HOT", "SALE", "FRESH")
│   ├── ecom_flash_sale_section.dart      # Orange countdown ticker [HH:MM:SS] + flame sold progress bars
│   └── ecom_product_card.dart            # Shopee-style 2-column product card (badges, rating, sold count, origin)
└── home_screen.dart                      # Refactored parent with CustomScrollView & sliver coordination
```

### 3.1 Component Specifications

#### A. EcomSliverAppBar (`ecom_sliver_app_bar.dart`)
- **Top Location Strip:** Tap to switch delivery address (`📍 Deliver to [Barangay/City] ▾`).
- **Unified Search Pill:** Rounded search field with animated rotating placeholder hints ("Search fresh strawberries...", "Search organic heirloom rice...").
- **Integrated Action Icons:**
  - In-bar QR/Camera icon for farm batch verification scanning.
  - Notification bell with dynamic unread indicator dot.
  - Cart icon with real-time reactive badge counter reflecting current cart total items.
- **Scroll Physics:** Smooth sliver collapse behavior from brand emerald header to sticky floating search bar.

#### B. EcomHeroBanner (`ecom_hero_banner.dart`)
- **Format:** 16:9 rounded promotional carousel.
- **Interaction:** Auto-sliding on a 4-second interval, pause-on-touch, with bottom-right floating pill indicator (`1/3`).
- **Routing:** Deep-links to featured promotional campaigns (e.g. Free Shipping Sunday, Benguet Harvest Fest).

#### C. EcomCategoryGrid (`ecom_category_grid.dart`)
- **Format:** 2-row horizontal-scroll matrix with circular squircle icons.
- **Categories:** Fresh Vegetables, Sweet Fruits, Rice & Grains, Poultry & Eggs, Fresh Seafood, Organic Harvest, Pre-Orders, and Wholesale B2B.
- **Micro-Badges:** Small tag chips ("HOT", "NEW", "50% OFF") overlaid on high-priority categories.

#### D. EcomFlashSaleSection (`ecom_flash_sale_section.dart`)
- **Header:** Vibrant orange-to-coral gradient bar featuring:
  - `⚡ FLASH DEALS` title
  - Real-time digital countdown box: `[ 02 ] : [ 45 ] : [ 18 ]`
  - `View All ❯` navigation link to full flash deals screen.
- **Horizontal Deal Cards:**
  - Produce preview image with discount ribbon (`-40%`).
  - Flash price in bold flame color (`₱45/kg`).
  - Stock claim bar (`🔥 78% Sold`) using custom progress bar with flame icon.

#### E. EcomProductCard (`ecom_product_card.dart`)
- **Format:** 2-column grid card with 1:1 square image ratio.
- **Visual Features:**
  - High-res image with fallback placeholder and rounded top corners.
  - Farm Verified Pill: `🌱 [Farm Name]`.
  - Product Title (2-line clamped with ellipsis).
  - Dual Pricing: Bold discounted price (`₱85`) + crossed-out SRP (`₱110`).
  - Trust & Social Proof: Star rating `★ 4.9 (42)` and sales volume `1.5k sold`.
  - Origin & Proximity: `📍 2.8 km away`.
  - Quick "+ Cart" floating button with micro-tap bounce feedback.

---

## 4. State Management, Real-Time Sync & Data Flow

1. **Reactive Services:**
   - `CartService`: Real-time reactive listener updating header cart counter badge across all user operations.
   - `NotificationService`: Live listener for unread notifications count.
   - `UserService`: Cached default delivery address displayed in the header location pill.
   - `SupabaseDataService`: Dual data stream querying active flash sale items and daily discovery produce.
2. **Timers & Lifecycle:**
   - Countdown timer running at a 1-second interval updating only the digital clock widget without rebuilding the whole tree.
   - Banner auto-play timer cleanly started on `initState` and cancelled on `dispose`.
3. **Resilience & Performance:**
   - High-fidelity shimmer skeleton loaders while network requests complete.
   - Seamless pull-to-refresh (`RefreshIndicator`) reloading banners, flash deals, and discovery items in parallel.
   - Offline browse mode with `OfflineCacheService` caching previously viewed produce items.

---

## 5. Testing & Verification

1. **Unit & Widget Tests:**
   - Verify countdown timer formatting (`HH:MM:SS`) and disposal.
   - Verify `EcomProductCard` rendering of discount percentages, strikethrough prices, ratings, and missing image fallbacks.
   - Verify Cart badge counter increments reactively when `CartService` state mutates.
2. **Integration & Navigation:**
   - Search bar tap -> `SearchScreen`.
   - QR tap -> `QRScannerScreen`.
   - Cart icon tap -> `CartScreen`.
   - Product card tap -> `ProductViewScreen`.
   - Flash Sale card tap -> `ProductViewScreen`.
3. **Static Analysis & Performance:**
   - Execute `flutter analyze` to guarantee zero errors and strict lint compliance.
   - Verify steady 60 FPS scrolling physics across the entire `CustomScrollView`.
