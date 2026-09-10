# Design Spec: Dedicated Web Notifications Screen

**Date**: 2026-09-07  
**Topic**: Desktop Web Notification Experience Parity & Redesign  
**Target Route**: `/notifications`  

---

## 1. Objective
Replace the mobile `NotificationsScreen` that is rendered directly on desktop browsers at `/notifications` with a dedicated, responsive, and aesthetically pleasing `WebNotificationsScreen`. The new screen will integrate into the AgriDirect Web Shell (standard web header, breadcrumbs, max-width container, and footer) while preserving mobile phone navigation on mobile screen sizes.

---

## 2. Architecture & Routing

### 2.1 Route Switching in `app_router.dart`
In [`lib/shared/router/app_router.dart`](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/shared/router/app_router.dart):
Update `AppRoutes.notifications`:
```dart
GoRoute(
  path: AppRoutes.notifications,
  builder: (context, state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (kIsWeb && constraints.maxWidth > 768) {
          return const WebNotificationsScreen();
        }
        return const NotificationsScreen();
      },
    );
  },
),
```

### 2.2 Dedicated Screen Component
- Location: [`lib/web/screens/consumer/web_notifications_screen.dart`](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/web/screens/consumer/web_notifications_screen.dart)
- Uses standard web structure matching [`WebCustomerOrdersScreen`](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/web/screens/consumer/web_customer_orders_screen.dart):
  - Column with [`WebEcomHeader`](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/web/widgets/ecom/web_ecom_header.dart)
  - `SingleChildScrollView` body with `ConstrainedBox(maxWidth: 1040)`
  - [`AgriDirectWebFooter`](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/web/widgets/web_footer.dart) at the bottom

---

## 3. Screen Design & Features

### 3.1 Header & Control Bar
- **Breadcrumbs**: `Home` > `Notifications` (clickable links to return to marketplace/home).
- **Title**: `Notifications` with dynamic badge displaying `X New` unread items.
- **Top Action Bar**:
  - **Mark all as read**: Calls `NotificationService().markAllAsRead(userId)` with toast confirmation.
  - **Clear all**: Shows a confirmation dialog, then clears notifications via `NotificationService().clearAllNotifications(userId)` or optimistic deletion.
  - **Refresh**: Pull-to-refresh / icon button to reload notifications.

### 3.2 Filtering & Search
- **Category Filter Pills**:
  - `All` (displays total count)
  - `Orders` (pre-orders, deliveries, order status)
  - `Weather AI` (rain advisories, storm warnings, weather alerts)
  - `Promos` (vouchers, discounts, sales)
  - `Community` (posts, comments, farmer updates)
- **Unread Only Toggle**: Quick filter to show only unread notifications.

### 3.3 Chronological Grouping
Notifications are grouped into:
- **TODAY**
- **YESTERDAY**
- **EARLIER**

### 3.4 Notification Card Visual Spec
- **Container**: White background card, `BorderRadius.circular(12)`, 1px border (`#E2E8F0`), subtle drop shadow on hover.
- **Unread Styling**: Soft green highlight (`#F0FDF4`), emerald left indicator line (3px), unread badge dot.
- **Category Icon Avatar**:
  - Weather: Amber icon & soft amber background
  - Order: Sky blue icon & soft sky blue background
  - Promo: Rose/Coral icon & soft rose background
  - Community: Purple/Indigo icon & soft indigo background
- **Content Area**:
  - Bold notification title
  - Notification body text
  - Relative time ago (e.g. `24m ago`, `Yesterday 3:15 PM`)
- **Card Actions**:
  - `View Details →` CTA button on the right
  - Dismiss/Delete button with undo option
  - Full card tap triggers deep-link routing via `NotificationService().navigateFromLink` and marks the item as read.

### 3.5 Empty State
- Centered cheerful icon (`Icons.notifications_none_rounded` or `Icons.mark_email_read_outlined`).
- Title: `All caught up!`
- Subtitle: `You don't have any notifications in this category right now.`
- Action: "Explore Marketplace" button returning to `/marketplace`.

---

## 4. Error Handling & Edge Cases
- **Not Logged In**: Show a friendly sign-in prompt card with "Log In" button redirecting to `/login`.
- **Loading State**: Subtle shimmer / skeleton cards or centered emerald progress indicator.
- **Network Errors**: Graceful fallback banner with retry button.
- **Deep-Link Fallback**: If `link_type` is unknown or missing, intelligently route to `/farmer/weather`, `/customer-orders`, or `/vouchers` based on keywords.

---

## 5. Testing & Verification
- Verify web desktop rendering at `maxWidth > 768` shows full web header, max-width 1040px centered feed, and footer.
- Verify mobile rendering shows mobile `NotificationsScreen` with mobile AppBar.
- Verify filtering (All, Orders, Weather, Promos, Community, Unread).
- Verify "Mark all as read" and "Delete" actions work and sync with database.
- Verify deep links navigate correctly to related screens.
