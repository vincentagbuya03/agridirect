# 3 Pages Comprehensive Design Specification

## Overview
Full layout overhaul and feature enhancement across 3 core web screens for AgriDirect:
1. **Product Management Page** (`lib/web/screens/farmer/web_farmer_products.dart`)
2. **Community Hub Page** (`lib/web/screens/farmer/web_community_hub.dart`)
3. **Profile & Settings Page** (`lib/web/screens/consumer/web_profile_screen.dart`)

---

## 1. Product Management Page (`web_farmer_products.dart`)

### Layout & Space Maximization
- **Container**: Full-width responsive container (`max-width: 1320px`).
- **4 KPI Metric Cards (Top Section)**:
  - Total Products (`Count + Trend`)
  - Inventory Valuation (`Total computed ₱ value`)
  - Stock Alerts (`Low stock / Out of stock count`)
  - Active Pre-Orders (`Pre-order count & potential earnings`)
- **Filter Toolbar**:
  - Live Search field with clear button.
  - Category filter chips (All, Vegetables, Fruits, Grains, Poultry, Pre-orders).
  - Stock Status filter dropdown.
  - View Mode switcher (Grid vs Data Table).
- **Responsive Product Grid**:
  - 4 columns on desktop (`>= 1100px`), 3 on tablet, 1-2 on mobile.
  - Product Card upgrades: Image with cover zoom hover, Stock progress bar (`45 / 100 kg`), Price/Unit badge, Pre-order badge, Quick Restock dialog button, Edit button, Delete button.

---

## 2. Community Hub Page (`web_community_hub.dart`)

### Widescreen 2-Column Feed & Sidebar Layout (`1320px` max width)
- **Left Main Feed (68% width)**:
  - Weather & Agro Advisory Header Banner.
  - Rich Post Creation Card: Avatar, Text input with placeholder, Tag selector (Pest, Market Price, Harvest, Equipment), Photo attachment button, Category dropdown, and Post Submit button.
  - Feed Category Tabs (`All Discussions`, `Market Price Updates`, `Pest & Diseases`, `Q&A`).
  - Interactive Post Cards: Author avatar with Verified Farmer badge, Timestamp, Category pill, Post content & images, Like button (with animation & counter), Comment toggle, Share, and inline Comment section.
- **Right Sidebar (32% width)**:
  - Local Weather Widget with 3-day forecast summary.
  - Live Market Price Reference widget (Palay, Eggs, Tomatoes, Onion).
  - Trending Hashtags / Topics list.
  - Top Community Contributors leaderboard with Follow buttons.

---

## 3. Profile & Settings Page (`web_profile_screen.dart`)

### Widescreen 2-Column Profile Dashboard (`1320px` max width)
- **Top Farm Hero Card**:
  - Cover background image, Farm avatar with edit overlay badge, Farm Name, Category tag, Location tag, Verified Seller badge, and Shop Status toggle switch (Open / Closed for orders).
- **4 KPI Performance Stat Cards**:
  - Total Orders Completed, Shop Rating (4.9 ★), Store Followers, Order Fulfillment Rate (98%).
- **Left Navigation Sidebar (35% width)**:
  - Mode Switcher card ("Switch to Customer Mode" / "Farmer Mode").
  - Quick Navigation List with badge indicators (My Products, Orders, Messages, Notifications, Security, Help).
  - Account Action Buttons (Edit Profile, Log Out).
- **Right Main Content Panel (65% width)**:
  - Farm Details & Address information card.
  - Shop Operating Hours & Delivery options card.
  - Quick Restock & Activity summary.
