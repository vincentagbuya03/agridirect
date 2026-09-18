# Design Specification: In-App Guided Spotlight Tour for Consumers and Farmers

**Date:** 2026-09-12  
**Status:** Approved  
**Topic:** In-App Step-by-Step Spotlight Coachmark Tour for New & First-Time Users (Consumer & Farmer parity)

---

## 1. Overview & Objectives

Provide a polished, professional, and visually engaging step-by-step in-app spotlight walkthrough (coachmark overlay) for both **Consumers** and **Farmers** upon their first time signing up or opening the AgriDirect dashboard.

### Core Goals:
- **Visual Excellence**: Dark dimmed backdrop (`0.72` opacity) with a rounded spotlight window and glowing emerald/gold halo surrounding active UI elements.
- **Card Experience**: Floating coachmark card with step counter (`Step X of Y`), dismiss `✕` button, feature title, friendly explanatory body, and animated `Back` / `Next` buttons.
- **Role Parity**: Seamless 5-step guided tours customized for Consumers (finding food, local farmers, pre-orders, cart, Kiko AI) and Farmers (daily earnings, adding products, orders, weather radar, community & payouts).
- **Persistence & Replayability**: Persisted once completed in `SharedPreferences` per role, with the option to replay on demand from the Profile / Help screen.

---

## 2. Architecture & Components

### 2.1 Reusable Spotlight Tour Framework
Create a standalone, decoupled widget package:
- `lib/shared/widgets/tour/spotlight_tour_controller.dart`: State controller managing current step, target keys, completion callback, and `SharedPreferences` persistence.
- `lib/shared/widgets/tour/spotlight_tour_overlay.dart`: Renders:
  - Custom `CutoutPainter` using `Path.combine(PathOperation.difference, ...)` with smooth corner radius.
  - Pulsing animated border around the cutout.
  - Positioned floating tooltip card with automatic top/bottom positioning relative to the target's screen coordinates.
- `lib/shared/widgets/tour/tour_step_model.dart`: Data class representing each step (target `GlobalKey`, title, description, badge text, optional icon).

### 2.2 Tour Steps Definition

#### Consumer Tour Steps (`consumer_tour_steps.dart`):
1. **Search & Categories**: Target top search field. Focus: discovering fresh produce and filtering by farm type.
2. **Farmers Map Hub**: Target farmers map shortcut. Focus: connecting directly with local producers.
3. **Pre-Order Hub**: Target pre-order tab / banner. Focus: booking future harvests at locked wholesale rates.
4. **Weather & Radar**: Target radar nav item. Focus: monitoring regional climate & rain forecasts.
5. **Cart & Assistant**: Target cart icon & Kiko AI. Focus: seamless checkout, order tracking, and instant support.

#### Farmer Tour Steps (`farmer_tour_steps.dart`):
1. **Farm Performance & Sales**: Target sales summary & metrics. Focus: total revenue, active listings, and sales trends.
2. **Weather Radar & AI Advisory**: Target weather widget. Focus: real-time rain radar, typhoon warnings, and Kiko AI crop tips.
3. **Add Produce & Manage Listings**: Target `+ Add Product` / quick operations. Focus: fast crop posting with photos and per-kg pricing.
4. **Orders & Dispatch**: Target orders navigation. Focus: fulfilling incoming customer orders and managing pre-orders.
5. **Buyer Chat & Community Hub**: Target messages & community tab. Focus: direct customer negotiations, answering questions, and sharing farm updates.

---

## 3. Integration Points

### 3.1 Consumer Dashboard Integration
- In `HomeScreen` (`lib/mobile/screens/consumer/home_screen.dart`):
  - Assign `GlobalKey`s to the relevant header and navigation widgets.
  - Check `SharedPreferences` key `agridirect_consumer_tour_completed`. If false or triggered manually, initiate the consumer tour after frame post-callback.

### 3.2 Farmer Dashboard Integration
- In `FarmerSalesDashboard` (`lib/mobile/screens/farmer/farmer_sales_dashboard.dart`):
  - Assign `GlobalKey`s to balance cards, add product button, orders, and weather.
  - Check `SharedPreferences` key `agridirect_farmer_tour_completed`. If false or triggered manually, initiate the farmer tour.

### 3.3 Replay Access in Settings & Help
- Add a `"Replay App Tour"` tile in `lib/mobile/screens/support/help_center_screen.dart` and `CustomerProfileScreen` / `FarmerProfileScreen` to reset the flag and re-launch the tour.

---

## 4. Error Handling & Edge Cases
- **Missing or Offscreen Target**: If a target widget hasn't rendered or is outside the viewport, safely fall back to centering the dialog card with an informational icon instead of crashing or misplacing cutouts.
- **Orientation & Screen Resizing**: Floating card positions re-measure on window metrics changes.
- **Fast Dismiss**: Pressing `✕` or tapping the dismiss button immediately terminates the overlay without blocking user interaction.
