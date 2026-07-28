# Design Spec: Mobile Profile Redesign (Option A with AgriDirect Brand)

This document outlines the design specification for the mobile Profile screen redesign, applying the card-grouped layout (Option A) to both Customer (Buyer) and Farmer profiles, using AgriDirect brand colors and typography.

## Goals
- Align the layout with the user-provided Option A design.
- Utilize AgriDirect colors: Emerald Green (`#059669`) for primary actions/badges, Amber (`#F59E0B`) for secondary badges/highlights, and Slate backgrounds (`#F8FAFC`).
- Ensure visual parity and high-quality layout styling for both `CustomerProfileScreen` and `FarmerProfileScreen`.

---

## User Review Required
No major architectural shifts or database changes. This is a frontend layout and styling update.

---

## Proposed Layout

### 1. Customer Profile (`CustomerProfileScreen`)
- **Background**: `AppColors.background` (`#F8FAFC`).
- **Header**:
  - Centered "Profile" text with custom leading back/close buttons.
  - Avatar, Name, Email, and "Premium Buyer" badge wrapped in a clean, padded card.
  - "Switch to Selling" / "Start Selling" banner or pill inside or below the header card.
- **Card 1: Account Settings** (Rounded card with custom outline icons):
  - My Details
  - Address Book
  - Favorites
  - My Vouchers
  - Messages
- **Card 2: Other** (Rounded card with custom outline icons):
  - Help Center
  - App Settings
- **Footer**:
  - Large Outlined/Tonal Logout Button with warning color context (`AppColors.error`).
  - Version footer text.

### 2. Farmer Profile (`FarmerProfileScreen`)
- **Background**: `AppColors.background` (`#F8FAFC`).
- **Header**:
  - Centered "Farmer Profile" text.
  - Avatar, Farm Name, Email, and "Verified Farmer" badge wrapped in a clean, padded card.
  - Stats row (Followers, Products, Posts) inside the header card.
  - "Switch to Buying" CTA pill or button.
- **Card 1: Business Settings** (Rounded card):
  - Sales Dashboard
  - My Products
  - Farm Details
  - Followers
  - Farmer Community
  - Manage Vouchers
- **Card 2: Support**:
  - Help Center
  - App Settings
- **Footer**:
  - Outlined logout button.

---

## Technical Details & Styling
- Use `AppColors.background` for the screen background.
- White containers for menu cards (`color: Colors.white`, border radius `24.0`, subtle shadow or light border).
- Outline icons from `Icons.*_outlined` or `Icons.*_rounded` to fit the clean, premium feel.
- Clean dividers with left/right padding between the items, excluding the last item.
