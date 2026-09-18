# In-App Guided Spotlight Tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a high-end, responsive in-app guided spotlight tour (coachmark walkthrough) for both Consumers and Farmers on first-time signup/login with replay options.

**Architecture:** A reusable `SpotlightTourOverlay` renders a dark scrim with a dynamic rounded-rectangle cutout and glowing halo over targeted widgets via `GlobalKey`. A floating, auto-positioning coachmark card displays progress (`Step X of 5`), feature copy, skip controls, and navigation buttons. State is managed via `SharedPreferences` to prevent unwanted re-runs while allowing intentional replaying from settings.

**Tech Stack:** Flutter, Dart, `SharedPreferences`, `GoogleFonts`, `AppColors` design system.

## Global Constraints
- Target platform: Flutter mobile (Android/iOS) with clean layout guards for responsive sizing.
- Colors: AgriDirect brand emerald (`#10B981`), dark surface (`#0F172A`), white card, subtle amber accents.
- Persistence keys: `agridirect_consumer_tour_completed` and `agridirect_farmer_tour_completed`.
- Safety: If a target key is off-screen or null, fallback gracefully to a centered modal card without crashing.

---

### Task 1: Create Spotlight Tour Models & Reusable Overlay Widget

**Files:**
- Create: `lib/shared/widgets/tour/tour_step_model.dart`
- Create: `lib/shared/widgets/tour/spotlight_tour_overlay.dart`
- Create: `lib/shared/widgets/tour/spotlight_tour_controller.dart`

**Interfaces:**
- Produces: `TourStepModel`, `SpotlightTourOverlay`, `SpotlightTourController.showTour(...)`

- [ ] **Step 1: Create `TourStepModel`**
  Define step data structure with target key, title, description, step index, total steps, and optional badge text.

- [ ] **Step 2: Create `SpotlightTourOverlay` with CustomPainter and Floating Card**
  Implement `CutoutPainter` using `PathOperation.difference` with rounded corners, animated glow effect around the target rect, and auto-positioning coachmark card.

- [ ] **Step 3: Create `SpotlightTourController`**
  Provide static helper `startTour(BuildContext context, {required List<TourStepModel> steps, required String prefKey})` that handles `SharedPreferences` checks and overlay insertion.

- [ ] **Step 4: Verify syntax and linting**
  Ensure imports and styling match AgriDirect standard theme.

- [ ] **Step 5: Commit**
  `git add lib/shared/widgets/tour; git commit -m "feat(tour): add spotlight coachmark overlay and tour controller"`

---

### Task 2: Configure Consumer and Farmer Tour Step Sets

**Files:**
- Create: `lib/shared/widgets/tour/consumer_tour_steps.dart`
- Create: `lib/shared/widgets/tour/farmer_tour_steps.dart`

**Interfaces:**
- Consumes: `TourStepModel`
- Produces: `getConsumerTourSteps(...)` and `getFarmerTourSteps(...)`

- [ ] **Step 1: Write `consumer_tour_steps.dart`**
  Create 5 steps targeting Search Bar, Farmers Map, Pre-Orders, Weather Radar, and Cart/Kiko AI with friendly consumer copy.

- [ ] **Step 2: Write `farmer_tour_steps.dart`**
  Create 5 steps targeting Sales Overview, Weather & Kiko Advisory, Add Harvest/Product, Orders Manager, and Direct Buyer Chat & Community.

- [ ] **Step 3: Commit**
  `git add lib/shared/widgets/tour; git commit -m "feat(tour): define consumer and farmer step configurations"`

---

### Task 3: Integrate Tour into Consumer Dashboard (`HomeScreen`)

**Files:**
- Modify: `lib/mobile/screens/consumer/home_screen.dart`

**Interfaces:**
- Consumes: `SpotlightTourController`, `getConsumerTourSteps`

- [ ] **Step 1: Attach `GlobalKey`s to key UI components**
  Assign `GlobalKey` to Search bar, map shortcut, pre-orders section, and top actions.

- [ ] **Step 2: Add post-frame auto-trigger logic**
  Check `agridirect_consumer_tour_completed`. If not completed, trigger `SpotlightTourController.startTour` after a 600ms delay.

- [ ] **Step 3: Commit**
  `git add lib/mobile/screens/consumer/home_screen.dart; git commit -m "feat(consumer): integrate first-time spotlight tour into HomeScreen"`

---

### Task 4: Integrate Tour into Farmer Dashboard (`FarmerSalesDashboard`)

**Files:**
- Modify: `lib/mobile/screens/farmer/farmer_sales_dashboard.dart`

**Interfaces:**
- Consumes: `SpotlightTourController`, `getFarmerTourSteps`

- [ ] **Step 1: Attach `GlobalKey`s to farmer dashboard components**
  Assign `GlobalKey` to earnings summary card, add product button, orders tab, and weather radar widget.

- [ ] **Step 2: Add post-frame auto-trigger logic**
  Check `agridirect_farmer_tour_completed`. If not completed, trigger `SpotlightTourController.startTour`.

- [ ] **Step 3: Commit**
  `git add lib/mobile/screens/farmer/farmer_sales_dashboard.dart; git commit -m "feat(farmer): integrate first-time spotlight tour into FarmerSalesDashboard"`

---

### Task 5: Add Replay Tour Option in Help Center and Profile Settings

**Files:**
- Modify: `lib/mobile/screens/support/help_center_screen.dart`
- Modify: `lib/mobile/screens/support/app_tour_screen.dart`

- [ ] **Step 1: Update `HelpCenterScreen` and `AppTourScreen`**
  Add interactive "Launch Interactive App Tour" button that resets the preference key and launches the spotlight tour on the active dashboard.

- [ ] **Step 2: Commit**
  `git add lib/mobile/screens/support; git commit -m "feat(support): add replay interactive tour option in help center"`

---

### Task 6: Analyze and Verify End-to-End

- [ ] **Step 1: Run Flutter analyze on touched files**
  Verify no syntax errors, missing imports, or type mismatches.

- [ ] **Step 2: Verify smooth build and execution**
