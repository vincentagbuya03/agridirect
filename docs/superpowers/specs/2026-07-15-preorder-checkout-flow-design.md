# Pre-order Checkout Flow & Harvest State Updates Design Doc

This design doc outlines the modifications required to improve the pre-order and checkout UX, specifically handling harvested pre-order products correctly and ensuring mobile consumers go through a proper checkout details screen instead of placing pre-orders immediately.

## Proposed Changes

### 1. Mobile Pre-order Detail Screen
File: [preorder_details_screen.dart](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/mobile/screens/consumer/preorder_details_screen.dart)
- Enable the action button even if the crop is harvested.
- Change the button text: if harvested, show **"Order Now"**; if not harvested, show **"Pre-order Now"**.
- Change the button action: instead of directly calling `_submit` (which instantly places the order), navigate to `AppRoutes.checkout` with the product, quantity, and `isPreOrder` flag (`!harvested`).

### 2. Mobile Pre-order Hub Screen
File: [preorder_hub_screen.dart](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/mobile/screens/consumer/preorder_hub_screen.dart)
- Add a helper `_isHarvested(ProductItem product)` method similar to the details screen.
- Update the action button on each pre-order card: if the crop is harvested, display **"ORDER NOW"** instead of "RESERVE HARVEST".

### 3. Web Pre-order Details Screen
File: [web_preorder_details.dart](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/web/screens/consumer/web_preorder_details.dart)
- Update the bottom action button text from "Buy Now" to **"Order Now"** if the crop is harvested.

### 4. Mobile Marketplace Details Screen
File: [marketplace_screen.dart](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/lib/mobile/screens/consumer/marketplace_screen.dart)
- Update `_buildHarvestBadge()` so that if the crop is harvested, the badge shows **"Ready Now"** or **"Order Now"** instead of "Pre-order".

---

## Verification Plan

### Manual Verification
1. Open the mobile marketplace details or preorder details of a harvested crop, verify that the button is active and displays "Order Now".
2. Tap "Pre-order Now" / "Order Now" on mobile details screen, verify it takes you to the Checkout screen with correct details.
3. Confirm that placing a pre-order now presents checkout details first (like addresses and COD/COP options) and requires confirmation.
