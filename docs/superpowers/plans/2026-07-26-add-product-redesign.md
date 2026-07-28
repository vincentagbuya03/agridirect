# Add / Edit Product Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Add / Edit Product screen (`lib/mobile/screens/farmer/add_product_screen.dart`) into a modern, 2-column split-screen layout with real-time marketplace card preview on desktop web, responsive stacked cards on mobile, polished input styling, and sticky action controls.

**Architecture:** Refactor `AddProductScreen` into modular, reusable sub-widgets (`_ProductLivePreviewCard`, `_ProductMediaUploadSection`, `_ProductBasicInfoForm`, `_ProductPricingInventoryForm`, `_ProductActionBar`). Wrap desktop view in a 2-column responsive layout (`Row` with `Flexible`/`Expanded` under `LayoutBuilder`) and mobile view in a single-column scrollable layout.

**Tech Stack:** Flutter, Dart, GoogleFonts (Plus Jakarta Sans / Inter), Supabase Data/Storage, GoRouter, ConnectivityPlus.

---

## Global Constraints
- Target screen: `lib/mobile/screens/farmer/add_product_screen.dart`
- Form state & submission logic must preserve existingSupabase, offline queue, and edit mode compatibility.
- Responsive breakpoint: `900px`.

---

### Task 1: Create Modular Components and Live Preview Widget

**Files:**
- Modify: `lib/mobile/screens/farmer/add_product_screen.dart`

**Interfaces:**
- Consumes: `_nameController`, `_priceController`, `_quantityController`, `_selectedCategory`, `_selectedUnit`, `_selectedImageFiles`
- Produces: `_buildLivePreviewCard()`, `_buildMediaUploadSection()`

- [ ] **Step 1: Refactor image picker and media grid into `_buildMediaUploadSection()`**
- [ ] **Step 2: Add real-time listener triggers on text controllers for live preview updates**
- [ ] **Step 3: Implement `_buildLivePreviewCard()` displaying real-time name, price/unit badge, category tag, and primary image preview**

---

### Task 2: Implement Widescreen 2-Column Responsive Layout & Sticky Action Bar

**Files:**
- Modify: `lib/mobile/screens/farmer/add_product_screen.dart`

**Interfaces:**
- Consumes: Form components from Task 1
- Produces: Complete desktop & mobile layout switcher

- [ ] **Step 1: Implement `LayoutBuilder` condition (`width >= 900`)**
- [ ] **Step 2: Build desktop 2-column view (`Left: Live Preview & Media Upload, Right: Form Input Cards`)**
- [ ] **Step 3: Add sticky bottom action bar with Cancel, Save Draft, and Publish Product CTA buttons**
- [ ] **Step 4: Verify mobile layout (`width < 900`) compatibility**
