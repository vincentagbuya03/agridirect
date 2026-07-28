# 3 Pages Comprehensive Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign and maximize screen space utilization across 3 primary web pages:
1. Product Management (`lib/web/screens/farmer/web_farmer_products.dart`)
2. Community Hub (`lib/web/screens/farmer/web_community_hub.dart`)
3. Profile & Account Settings (`lib/web/screens/consumer/web_profile_screen.dart`)

**Architecture:** 
- `web_farmer_products.dart`: Add top 4 KPI metric cards, Category & Stock Status filter toolbars, view mode toggle, and 4-column responsive product grid with stock progress indicators and quick restock actions.
- `web_community_hub.dart`: Maximize width with a 2-column layout (68% feed / 32% sidebar), add Market Price Trends widget, weather widget, post category filters, and interactive post card controls.
- `web_profile_screen.dart`: Transform into a 2-column Widescreen Profile Dashboard with top Farm Hero cover, 4 Shop Performance metrics, left navigation sidebar, and right farm details & shop operational settings panel.

**Tech Stack:** Flutter, Dart, GoogleFonts, Supabase, CachedNetworkImage.

---

## Global Constraints
- Target files:
  - `lib/web/screens/farmer/web_farmer_products.dart`
  - `lib/web/screens/farmer/web_community_hub.dart`
  - `lib/web/screens/consumer/web_profile_screen.dart`
- Desktop container max-width: `1320px`.
- Retain existing backend state & Supabase data bindings.

---

### Task 1: Redesign Product Management Page (`web_farmer_products.dart`)
**Files:**
- Modify: `lib/web/screens/farmer/web_farmer_products.dart`

- [ ] **Step 1: Implement 4 KPI Metric Summary Cards (Total Products, Inventory Value, Low Stock Count, Active Pre-Orders)**
- [ ] **Step 2: Add Category Filter Chips, Stock Status Filter Dropdown, and Search Control Bar**
- [ ] **Step 3: Enhance Product Grid Card layout with stock progress bars, price/unit badges, and quick restock dialog action**
- [ ] **Step 4: Expand container width to `1320px` max width for desktop widescreen displays**

### Task 2: Redesign Community Hub Page (`web_community_hub.dart`)
**Files:**
- Modify: `lib/web/screens/farmer/web_community_hub.dart`

- [ ] **Step 1: Implement 2-column widescreen container (`1320px` max width) with 68% feed / 32% sidebar ratio**
- [ ] **Step 2: Enhance post composer card with category tags and image attachment triggers**
- [ ] **Step 3: Add Feed Category Filter Tabs (All, Market Prices, Pest & Diseases, Q&A)**
- [ ] **Step 4: Build Market Price Trends Widget & Top Contributors Leaderboard in right sidebar**

### Task 3: Redesign Profile & Settings Page (`web_profile_screen.dart`)
**Files:**
- Modify: `lib/web/screens/consumer/web_profile_screen.dart`

- [ ] **Step 1: Build Top Farm Hero Header with cover image, avatar edit overlay, verified badge, and Shop Status toggle**
- [ ] **Step 2: Add 4 Shop Performance Overview Stat Cards (Total Orders, Rating, Followers, Fulfillment Rate)**
- [ ] **Step 3: Build 2-column profile layout with Left Navigation Sidebar (35%) and Right Details & Settings Panel (65%)**
- [ ] **Step 4: Verify full responsiveness across desktop, tablet, and mobile viewports**
