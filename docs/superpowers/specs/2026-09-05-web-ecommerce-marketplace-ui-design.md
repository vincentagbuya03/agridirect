# AgriDirect Web E-Commerce & Marketplace UI Design Specification

- **Document ID**: `2026-09-05-web-ecommerce-marketplace-ui-design`
- **Date**: September 5, 2026
- **Status**: Validated Design Spec (Approved by User)
- **Target Platform**: Flutter Web (Responsive: Desktop Extra-Wide ≥1440px, Desktop Standard 1024px–1439px, Tablet 768px–1023px, Mobile Web <768px)
- **Primary Aesthetic**: AgriDirect Hybrid (Clean Emerald/Slate Biophilic Palette + High-Conversion E-Commerce & Marketplace Mechanics)

---

## 1. Executive Summary & Vision

AgriDirect's web interface is transforming from a basic web portal into a **flagship agricultural e-commerce and multi-vendor marketplace**. The redesign mirrors premier marketplace standards (Amazon search precision, Shopee multi-vendor cart grouping and flash deal mechanics, and Thrive Market farm-to-table editorial elegance) while honoring AgriDirect's mission of empowering local Pangasinan farmers (San Carlos City cooperatives and growers).

The architecture transitions from legacy monolithic screen files (2,000–3,000 lines) into a **modular, component-driven Flutter Web e-commerce architecture** featuring reusable atomic components, standard design tokens, and smooth micro-interactions.

---

## 2. Design System & Foundational Tokens

### 2.1 Color Palette & Semantics
- **Brand Primary**: Emerald Green (`#16A34A` / `0xFF16A34A`), Deep Forest (`#14532D` / `0xFF14532D`), Soft Mint Surface (`#F0FDF4` / `0xFFF0FDF4`).
- **Neutrals & Typography**:
  - Dark Headings / Text: Slate 900 (`#0F172A` / `0xFF0F172A`).
  - Secondary / Body Text: Slate 600 (`#475569` / `0xFF475569`).
  - Muted / Captions: Slate 400 (`#94A3B8` / `0xFF94A3B8`).
  - Dividers & Borders: Light Gray (`#E2E8F0` / `0xFFE2E8F0`).
  - Canvas / Background: Off-white Warm Neutral (`#F8FAFC` / `0xFFF8FAFC`).
  - Surface Card: Pure White (`#FFFFFF` / `0xFFFFFFFF`).
- **E-Commerce Accents**:
  - Flash Sale & Deal Countdown: Harvest Amber / Flame (`#EA580C` / `0xFFEA580C`).
  - Discount Badges & Stock Scarcity: Deep Crimson (`#DC2626` / `0xFFDC2626`).
  - Verified Grower Trust Badges: Marine Blue (`#2563EB` / `0xFF2563EB`).
  - Organic / Eco Badges: Sage Green (`#059669` / `0xFF059669`).

### 2.2 Typography Pairings (Google Fonts)
- **Headings, Prices & Numerical Badges**: `GoogleFonts.rubik()`
  - Bold 700 / Semi-Bold 600 for product names, price tags, and hero headlines.
  - Excellent tabular number rendering for currency values (`₱XX.XX`).
- **Body, Navigation, Filters & Technical Details**: `GoogleFonts.nunitoSans()`
  - Regular 400 / Medium 500 for high readability in multi-line descriptions, farm timelines, and filter controls.

### 2.3 Grid System, Containers & Responsive Breakpoints
- **Desktop Extra-Wide (≥1440px)**:
  - Max Container Width: `1360px`, centered with `EdgeInsets.symmetric(horizontal: 40)`.
  - Grid: 12-column grid. Product catalogs display in **5 columns** or **4 columns** based on density toggle.
- **Desktop Standard (1024px – 1439px)**:
  - Max Container Width: `1100px`, centered with `EdgeInsets.symmetric(horizontal: 24)`.
  - Grid: 12-column grid. Product catalogs display in **4 columns**.
- **Tablet / Laptop Compact (768px – 1023px)**:
  - Content fluid width with `EdgeInsets.symmetric(horizontal: 16)`.
  - Filter sidebar collapses into a slide-over modal drawer.
  - Product catalogs display in **3 columns**.
- **Mobile Web (<768px)**:
  - Content fluid width with `EdgeInsets.symmetric(horizontal: 12)`.
  - Product catalogs display in **2 columns**.
  - Top navigation collapses into a slide drawer + sticky bottom navigation bar.

### 2.4 Micro-Interactions & Elevational Depth
- **Card Hover Depth**:
  - Rest state: Elevation 0, subtle 1px border (`0xFFE2E8F0`), `BorderRadius.circular(16)`.
  - Hover state: Elevation 3 (`BoxShadow(color: Color(0x140F172A), blurRadius: 20, offset: Offset(0, 8))`), translateY `-4px` via `Matrix4.translationValues(0, -4, 0)` with 200ms ease-out curve.
- **Image Hover Zoom**:
  - Product card images scale to `1.05x` inside an `AnimatedScale` wrapped in `ClipRRect`.
- **Loading & Skeleton Shimmer**:
  - Standardized `AppShimmerLoader` shapes matching exact card dimensions (aspect ratio 1:1 image + text blocks).

---

## 3. Global Navigation & Omnibar Architecture

### 3.1 Three-Tier Sticky Header Hierarchy
Located in `lib/web/widgets/ecom/web_ecom_header.dart` (replacing legacy `web_consumer_nav_bar.dart` on consumer routes).

```
+---------------------------------------------------------------------------------------------------+
| Top Utility Strip: Deliver to: [San Carlos City ▾] | Farm-Direct Ticker | Track Order | Farmer Portal|
+---------------------------------------------------------------------------------------------------+
| Main Omnibar: [Logo] | [All Categories ▾] [ Omnibar Search Input... 🔍 ] | [Chat] [Notif] [Cart(3)]|
+---------------------------------------------------------------------------------------------------+
| Mega-Menu Bar: 🥬 Vegetables | 🍎 Fruits | 🌾 Rice | ⚡ Flash Sale | 📦 Pre-Orders | 🚜 Farmers   |
+---------------------------------------------------------------------------------------------------+
```

#### Tier 1: Top Utility Strip (28px height)
- **Left**: Location selector: `"Deliver to: 📍 San Carlos City, Pangasinan"` with click-to-open Barangay Picker Modal (allows switching between 86 barangays to accurately calculate delivery times and distance).
- **Center**: Dynamic Farm-Direct Announcement Ticker (e.g., *"🌾 100% Direct from Pangasinan Farmers • Free Delivery on orders ₱500+"*).
- **Right**:
  - `"Sell on AgriDirect / Farmer Portal"` link (quick toggle for dual-role users).
  - `"Track Harvest / My Orders"`.
  - `"Help & FAQs"`.

#### Tier 2: Main Omnibar Header (72px height, sticky with 92% glassmorphism blur)
- **Brand Identity**: High-res SVG AgriDirect Logo with emerald accent.
- **Category Filter Dropdown**: Compact selector allowing instant search scoping (All, Fresh Vegetables, Rice & Grains, Fruits, Organic).
- **Central Omnibar Search**:
  - Real-time search query input with clear `(X)` button.
  - Live suggestion overlay popup showing:
    1. Top matching harvest crops with thumbnail and current price.
    2. Verified local farmers matching query.
    3. Recent searches stored in local session.
  - Prominent search action button with magnifying glass.
- **Action Cluster**:
  - **Farmer Chat**: Direct message icon with unread badge counter.
  - **Notification Center**: Bell icon with unread ping indicator and popup flyout.
  - **Wishlist**: Heart icon with badge count.
  - **Interactive Cart Flyout**:
    - Displays bag icon + live item count badge + running subtotal.
    - Hovering or tapping reveals an interactive mini-cart dropdown:
      - List of top 3 recently added produce items with quantities and prices.
      - Item count and subtotal calculation.
      - "View Cart" secondary button and "Instant Checkout" emerald button.
  - **User Profile & Account Menu**:
    - Avatar, user name, and role pill (`Consumer`).
    - Dropdown options: My Orders, Delivery Addresses, AgriVouchers, Account Settings, Switch Mode, Logout.

#### Tier 3: Department Mega-Menu Bar (44px height)
- Horizontal category tabs:
  - `🥬 Fresh Vegetables`
  - `🍎 Fruits`
  - `🌾 Grains & Rice`
  - `🌱 Organic & Hydroponic`
  - `⚡ Flash Deals`
  - `📦 Pre-Orders / Harvest Radar`
  - `🚜 Verified Farmer Directory`
  - `🏷️ AgriVouchers & Promos`
- Interactive hover underline with smooth spring animation.

---

## 4. Marketplace Home Page Architecture (`web_marketplace_home.dart`)

### 4.1 Section Layout Breakdown
```
1. [Hero Bento Grid: Main Carousel (8 cols) + Dual Micro-Deals (4 cols)]
2. [Value Proposition & Trust Badge Strip (4 Pillars)]
3. [Visual Harvest Category Slider (Circular Crop Tiles)]
4. [Flash Harvest Sale Strip (Live Countdown + Stock Meter)]
5. [Featured Farmer Storefront Spotlight (Local Cooperatives)]
6. [Curated & Trending Farm Produce Grid (Faceted Tabs + 5-Col Grid)]
7. [Agricultural Articles & Harvest Radar Preview]
8. [Direct Farmer Impact Counter (Stats & Transparency)]
9. [Enterprise E-Commerce Footer]
```

### 4.2 Component Specifications

#### 1. Hero Bento Grid
- Left Carousel (8/12 width):
  - Autoplaying carousel with 3 high-impact promotional banners (e.g., *"San Carlos Fresh Harvest Festival"*, *"Pre-Order In-Demand Mangoes & Rice"*, *"Direct Farm-to-Kitchen Wholesale"*).
  - Clean text typography, gradient overlay for high text legibility, dual CTA buttons (*"Shop Today's Harvest"*, *"Explore Pre-Orders"*).
- Right Side Promo Micro-Cards (4/12 width):
  - Card A: **Flash Deal Spotlight** with dynamic countdown timer, featured product photo, and discount pill.
  - Card B: **Meet the Farmer Spotlight** featuring an active cooperative with verified badge and 1-click visit link.

#### 2. Value Proposition Strip
4 responsive cards with subtle borders and icon illustration:
- `🌾 100% Farm-Direct`: Zero middlemen, maximum income to Pangasinan growers.
- `🚚 Same-Day & Scheduled Delivery`: Direct from harvest fields to doorstep.
- `⭐ Verified Local Cooperatives`: Government-registered farmers and GAP-certified crops.
- `🔒 AgriDirect Escrow & COD`: Safe payments via GCash, Maya, Bank Transfer, or Cash on Delivery.

#### 3. Visual Harvest Category Slider
- Interactive circular/rounded cards showing crisp crop imagery (Tomatoes, Eggplant, Leafy Greens, Rice Varieties, Tropical Fruits, Herbs & Spices).
- Hover effect: Scale up 1.08x with soft green ring indicator and item count badge.

#### 4. Dynamic Flash Deals Section
- Flame Header: `⚡ Flash Harvest Deals` + Live Countdown Timer (HH:MM:SS) syncing with active promotions.
- Deal Cards:
  - Product image with `-25% OFF` discount pill.
  - Real-time stock progress bar: `🔥 78% Claimed - Only 6 kg left!`.
  - One-click `"Add to Cart"` action button.

#### 5. Featured Farmer Storefront Spotlight
- Horizontal showcase of leading local growers:
  - Farm photo / Farmer portrait, Farm name (e.g., *"San Carlos Organic Producers Cooperative"*), Barangay location badge.
  - Trust stats: ⭐ 4.9 Rating (340 reviews), 100% On-Time Delivery.
  - Thumbnail row of their 3 freshest crops.
  - Action: `"Visit Farm Storefront"`.

#### 6. Curated & Trending Product Grid
- Tabbed filters: `🔥 Trending Now`, `🌿 Fresh Harvest Today`, `⭐ Highest Rated`, `📦 Pre-Order Specials`.
- 5-column responsive grid utilizing `WebProductCard` with hover actions (Quick View modal, Add to Cart, Origin badge, Bulk discount tag).

---

## 5. Shop Catalog & Faceted Search Architecture (`web_shop_screen.dart`)

### 5.1 Layout & Grid Structure
- **Left Column (3/12 width, 280px sticky)**: `WebFilterSidebar`.
- **Right Column (9/12 width, remaining)**:
  - Header Toolbar: Breadcrumbs, category headline, active filter pill strip, results counter, density switcher (3 vs 4 vs 5 columns / list view), sort selector.
  - Product Catalog Grid.
  - Pagination Controls.

### 5.2 Faceted Sidebar Filter (`WebFilterSidebar`)
1. **Barangay / Location Scope**:
   - Checkbox list with search bar for Pangasinan Barangays (Roxas, Baleyadaan, Tarece, Malabago, etc.).
   - Distance radius slider (`Within 5km`, `Within 15km`, `All San Carlos`).
2. **Harvest Freshness**:
   - Radio options: All, Harvested Today (<24h), Harvested in last 48h, Pre-Order (Next harvest window).
3. **Farming Method & Certification**:
   - Checkboxes: 100% Organic, Good Agricultural Practices (GAP) Certified, Hydroponic, Traditional/Conventional.
4. **Price Range (₱)**:
   - Dual-handle range slider + dual Min/Max text input fields with instant filter debounce (300ms).
5. **Farmer Rating**:
   - 4 Stars & Up, 3 Stars & Up, Verified Cooperatives Only.
6. **Availability & Deals**:
   - In Stock Now, Pre-Order Available, Flash Sale Discount, Free Delivery Eligible, Wholesale/Bulk Pricing.

### 5.3 Interactive Quick View Modal (`WebProductQuickViewDialog`)
- Accessible from any product card hover state without page reload.
- Renders:
  - Product image gallery.
  - Farmer name and barangay origin.
  - Full price and wholesale tier table.
  - Quantity selector (+ / -).
  - Direct "Add to Cart" and "Buy Now" CTA buttons.
  - "View Complete Details" link navigating to the full product page.

---

## 6. Product Details & Farm Trust Architecture (`web_product_details.dart`)

### 6.1 Two-Column Product Layout (50/50 Split)
#### Left Column: Media & Visual Verification
- Main high-resolution image viewer with smooth hover magnifier lens.
- Horizontal thumbnail strip for multiple angles or harvest batch photos.
- Farmer video harvest clip badge (if available).
- Origin stamp: `📍 Harvested in Brgy. Baleyadaan, San Carlos City`.

#### Right Column: Purchase & Transparency Engine
1. **Title & Badges**:
   - Product Name (Rubik Bold 26px).
   - Category Breadcrumb: `Home / Shop / Vegetables / Root Crops`.
   - Badges: `🌿 100% Organic`, `🌾 Farm-Direct`, `⚡ Flash Sale`.
2. **Ratings & Social Proof**:
   - Star rating (`⭐ 4.9`), 86 customer ratings, 1.2k kg sold.
3. **Price & Wholesale Tier Calculator**:
   - Retail Price: `₱45.00 / kg` (Strikethrough `₱60.00`, `-25%`).
   - Bulk Tier Card:
     - `1 – 9 kg`: ₱45 / kg
     - `10 – 49 kg`: ₱40 / kg (Save 11%)
     - `50+ kg`: ₱35 / kg (Save 22% - Ideal for resellers & restaurants)
4. **Harvest & Freshness Timeline**:
   - Illustrated milestone line:
     - 🌱 *Planted: May 15* ➔ 🌾 *Harvested: Yesterday 6:00 AM* ➔ 🚚 *Ready for Delivery*.
     - Shelf Life indicator: *Best consumed within 6 days*.
5. **Delivery & Logistics Estimator**:
   - Interactive Barangay delivery calculator with estimated delivery time (*"Order within 2 hrs for Tomorrow Morning delivery"*).
6. **Quantity & Action Controls**:
   - Step counter with keyboard input and minimum/maximum constraints.
   - Available stock counter (`Only 18 kg remaining in this batch`).
   - Action buttons:
     - `Add to Cart` (Secondary emerald outline button, 52px height).
     - `Buy Now` (Primary solid emerald button, 52px height, instant checkout transition).

### 6.2 Official Farm Storefront Card (`WebFarmStorefrontCard`)
- Dedicated card anchoring the product to its local grower:
  - Farm avatar/logo, Farm Name, Cooperative Affiliation.
  - Farmer Name (*"Mang Juan Dizon"*), Member since 2024.
  - Verified Grower checkmark (`#2563EB`).
  - Key Performance Metrics:
    - **Response Rate**: 98% (Responds within minutes).
    - **Fulfillment Rating**: 4.9 / 5.0.
    - **Total Harvests Sold**: 3,450 kg.
  - Actions:
    - `"Chat with Farmer"` button (opens messaging modal).
    - `"Visit Storefront"` button (navigates to farmer's full web profile).

### 6.3 Tabbed Technical Details & Customer Reviews
- **Tab 1: Produce Specifications**:
  - Variety, Farming Practice, Soil Type, Packaging Type (eco-friendly kraft / crate), Storage instructions.
- **Tab 2: Customer Reviews & Harvest Photos**:
  - Filter reviews by rating (5 stars, 4 stars, with photos).
  - Customer review cards with verified buyer badge, delivery timestamp, review text, and photo attachments.
  - Farmer direct replies (*"Salamat po sa pagtangkilik sa aming ani!"*).
- **Tab 3: More Fresh Picks from this Farmer**:
  - 4-column carousel of other active listings from the same farm.

---

## 7. Multi-Farm Cart & Streamlined Checkout Architecture

### 7.1 Multi-Vendor Grouped Cart (`web_cart_screen.dart`)
Standard modern e-commerce multi-vendor cart model:
```
+-------------------------------------------------------------+-----------------------+
| [✓ Select All (3 items)]                                    | Order Summary         |
|                                                             |                       |
| +---------------------------------------------------------+ | Subtotal:      ₱420.00|
| | [✓] 🚜 Mang Juan's Organic Farm (Brgy. Roxas)    [Chat] | | Delivery:       ₱70.00|
| |     Voucher: [₱20 OFF on ₱300 orders] [Claimed]         | | Voucher:       -₱20.00|
| | ------------------------------------------------------- | |                       |
| | [✓] [Img] Native Tomatoes 2kg   ₱45/kg   [- 2 +]  ₱90.00| | Total:         ₱470.00|
| | [✓] [Img] Fresh Eggplant 3kg    ₱50/kg   [- 3 +] ₱150.00| |                       |
| | Fulfillment: [● Farm Delivery]  [○ Cooperative Pickup]  | | [ Proceed to Checkout ]|
| +---------------------------------------------------------+ |                       |
|                                                             | 🔒 Guaranteed Safe    |
| +---------------------------------------------------------+ | GCash • Maya • COD    |
| | [✓] 🚜 San Carlos Rice Farmers Cooperative       [Chat] | |                       |
| | [✓] [Img] Dinorado Rice 5kg     ₱55/kg   [- 1 +] ₱180.00| |                       |
| +---------------------------------------------------------+ |                       |
+-------------------------------------------------------------+-----------------------+
```

1. **Per-Farm Grouping**:
   - Checkbox to select/unselect all items from a specific farm.
   - Farm header with Chat button and Barangay origin.
   - Farm-specific delivery notes and voucher selector.
2. **Product Rows**:
   - Thumbnail, title, unit price, stepper quantity, line item total, remove button.
3. **Sticky Order Summary (Right Column)**:
   - Dynamic real-time calculation based strictly on *selected* items.
   - Transparent delivery fee breakdown (single delivery fee if consolidated, or per-farm logistics).
   - Promo code input with instant validation.
   - One-click `"Proceed to Checkout"` button.

### 7.2 Modern Web Checkout Screen (`web_cart_checkout_screen.dart`)
- 3-Step Guided Breadcrumb:
  1. `1. Delivery Address & Barangay`
  2. `2. Logistics & Payment Method` (GCash, Maya, Bank Transfer, COD)
  3. `3. Order Review & Harvest Confirmation`
- Clean two-column desktop layout with sticky order confirmation details.

---

## 8. Modular Implementation Phasing

To ensure safe, production-grade delivery without breaking active features, the transformation is structured into 5 logical phases:

| Phase | Focus Area | Key Deliverables & Target Files |
|---|---|---|
| **Phase 1** | **Design System & Global Header Omnibar** | Design tokens (`WebDesignTokens`), `WebEcomHeader`, `WebOmnibarSearch`, `WebCartFlyout`, location picker modal. |
| **Phase 2** | **Marketplace Home Storefront Overhaul** | `WebMarketplaceHome` refactor, Hero Bento Grid, Trust Badge Strip, Visual Category Carousel, Flash Sale Strip, Featured Farmers showcase. |
| **Phase 3** | **Shop Catalog & Faceted Search** | `WebShopScreen` refactor, `WebFilterSidebar`, `WebProductCard` with hover zoom/quick-add, `WebProductQuickViewDialog`, pagination and density controls. |
| **Phase 4** | **Product Details & Farm Trust Card** | `WebProductDetails` refactor, 50/50 desktop layout, image magnifier gallery, `WebFarmStorefrontCard`, wholesale pricing tier table, harvest timeline, tabbed reviews. |
| **Phase 5** | **Multi-Farm Cart & Streamlined Checkout** | `WebCartScreen` & `WebCartCheckoutScreen` refactor, multi-farm grouped cart cards, sticky order summary, voucher integration, and complete responsive testing. |

---

## 9. Verification & Quality Assurance Strategy

1. **Static Analysis & Type Integrity**:
   - Execute `flutter analyze` ensuring zero compiler errors, null safety compliance, and deprecated widget elimination.
2. **Responsive Layout Audits**:
   - Validate across 4 standard screen breakpoints: 1440px (Desktop), 1200px (Laptop), 840px (Tablet), and 400px (Mobile Web).
   - Verify zero overflow errors (`RenderFlex overflowed`) across all pages.
3. **Micro-Interaction & State Verification**:
   - Verify smooth card hover elevations, image zoom animations, and dialog overlays.
   - Verify real-time cart badge reactivity across all screens via `CartService`.
4. **Parity & Data Integrity**:
   - Ensure complete backward compatibility with existing Supabase data models (`ProductItem`, `FarmerProfile`, `ProductReview`, `Voucher`).
