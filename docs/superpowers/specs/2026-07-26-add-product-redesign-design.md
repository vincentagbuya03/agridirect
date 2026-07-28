# Add / Edit Product Page Design Specification

## Overview
Redesign of the **Add / Edit Product** screen (`lib/mobile/screens/farmer/add_product_screen.dart`) to deliver a modern, high-converting split-screen responsive interface with real-time product card previews for desktop web while maintaining full mobile responsiveness.

---

## Layout & Responsive Architecture

### Breakpoint Strategy
- **Desktop Grid (`>= 900px`)**:
  - Max container width: `1280px` centered with side padding.
  - Left Column (40% width / 5 cols): Media Upload Grid + Sticky Live Marketplace Product Preview Card.
  - Right Column (60% width / 7 cols): Grouped Form Cards (Basic Details, Category & Pricing, Inventory & Pre-order Settings).
- **Mobile Stack (`< 900px`)**:
  - Single column scroll view.
  - Stack order: Header -> Live Preview Toggle/Card -> Media Upload -> Basic Details -> Pricing & Category -> Stock & Harvest -> Sticky Bottom Action Bar.

---

## Visual Design & Styling Standards

### Palette & Colors
- **Primary Accent**: `AppColors.primary` (`#2E7D32` / `#16A34A`)
- **Background**: Slate Tint `#F8FAFC`
- **Surface Cards**: `#FFFFFF` with `16px` rounded radius, `1px` subtle border `#E2E8F0`, and light shadow `Offset(0, 4), blurRadius: 16, color: rgba(0,0,0,0.04)`.
- **Typography**: Google Fonts (Plus Jakarta Sans / Inter), bold section headings (`fontSize: 16-18`, `fontWeight: w700`), crisp muted body labels (`#64748B`).

### Interactive Form Controls
- **Input Fields**: `12px` border radius, `#F8FAFC` background, focus outline with `AppColors.primary`.
- **Media Upload**: Dashed border upload target, thumbnail grid with hover delete buttons, cover image selector, and image count tracker (`0 / 5`).
- **Live Preview Card**: Mimics exact buyer UI card in AgriDirect marketplace, automatically updating product name, price/unit badge, category tag, and image as the farmer fills out the form.
- **Pre-Order Switch**: Custom switch card animating open harvest schedule inputs when toggled ON.

---

## Sticky Action Bar & States
- **Actions**:
  - Secondary: "Cancel", "Save Draft"
  - Primary CTA: "Publish Product" / "Update Product" with loading spinner state and success toast.
- **Offline / Online Banner**: Real-time status indicator pill in the top header.
