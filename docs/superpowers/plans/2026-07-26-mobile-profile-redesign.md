# Mobile Profile Redesign (Option A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign both Customer and Farmer profile screens in the mobile application to match Option A (grouped categories in cards) using AgriDirect colors and brand aesthetics.

**Architecture:** Modify `CustomerProfileScreen` and `FarmerProfileScreen` to structure menu items into styled category cards with outline icons and modern spacing, aligned with the existing routing and state logic.

**Tech Stack:** Flutter, GoRouter, Supabase.

## Global Constraints
- Target Files:
  - `lib/mobile/screens/consumer/customer_profile_screen.dart`
  - `lib/mobile/screens/farmer/farmer_profile_screen.dart`
- Colors: `AppColors.background` (`#F8FAFC`), `AppColors.primary` (`#059669`), `AppColors.accent` (`#F59E0B`), and Slate text styles.
- Components: White card containers with `borderRadius: BorderRadius.circular(24)`, outline icons, and clean dividers.

---

### Task 1: Redesign Customer Profile Screen

**Files:**
- Modify: `lib/mobile/screens/consumer/customer_profile_screen.dart`

- [ ] **Step 1: Implement Centered Header Bar & Card**
  Update the top app bar area to use a centered "Profile" title with a back button (shown only if the navigator can pop) and build a unified header card.
  ```dart
  // Replace the old header code with a clean row and card structure.
  // The header card should hold:
  // - Circular profile image with emerald border
  // - User name, email, and "Premium Buyer" badge
  // - "Switch to Selling" / "Start Selling" action button
  ```

- [ ] **Step 2: Implement Grouped Menu Cards (Account & Other)**
  Group the items inside cards using outline icons and clean dividers.
  * Card 1 (Account Settings): My Details, Address Book, Favorites, My Vouchers, Messages.
  * Card 2 (Other): Help Center, App Settings.

- [ ] **Step 3: Update Logout Button and Version Info**
  Style the Logout button as an outlined/tonal button using low-opacity error color, and center the version text at the bottom.

- [ ] **Step 4: Verify Compilation**
  Verify the modified file compiles successfully.

---

### Task 2: Redesign Farmer Profile Screen

**Files:**
- Modify: `lib/mobile/screens/farmer/farmer_profile_screen.dart`

- [ ] **Step 1: Implement Centered Header Bar & Card**
  Update the top app bar to be centered ("Farmer Profile") and style the Farmer header card.
  * Hold avatar with gold/accent border.
  * Hold farm name, email, and "Verified Farmer" badge.
  * Include the Stats Strip (Followers, Products, Posts) and the "Switch to Buying" button inside the card.

- [ ] **Step 2: Implement Grouped Menu Cards (Business Settings & Support)**
  Group items into white cards:
  * Card 1 (Business Settings): Sales Dashboard, My Products, Farm Details, Followers, Farmer Community, Manage Vouchers.
  * Card 2 (Support): Help Center, App Settings.

- [ ] **Step 3: Update Logout Button and Version Info**
  Style the Outlined Logout Button to match Task 1 design.

- [ ] **Step 4: Verify Compilation**
  Verify that `FarmerProfileScreen` compiles without errors.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure code contains no static analysis errors.

### Manual Verification
- Launch the mobile app and navigate to the Customer Profile screen to check the card groups, outline icons, and header alignment.
- Switch to Farmer Mode and verify the Farmer Profile screen stats, groups, and cards are rendered correctly.
