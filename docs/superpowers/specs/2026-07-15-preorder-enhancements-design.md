# Pre-order Enhancements: Milestones, Reminders, and Batch Target Alerts

This design document specifies the implementation of crop growth milestones, harvest countdowns/reminders, and batch target alerts for pre-order products on mobile and web.

## Proposed Design

### 1. Crop Growth Milestones & Photo Updates (Mobile & Web)
- **Database Schema**: Utilizes existing `crop_milestones` table.
- **Farmer Mobile UI**: 
  - Add a **"Post Update"** button on pre-order product cards in `farmer_products_screen.dart`.
  - Opens a mobile form dialog to input `title` (e.g. Sprouting 🌱), `description`, and `imageUrl` (optional).
- **Consumer Mobile UI**:
  - Integrate `CropMilestonesTimeline` in `preorder_details_screen.dart` under the product details section.
  - Fetch milestones using `ProductService().getCropMilestones(product.productId!)` on initialization.

### 2. Smart Harvest Countdowns & Automated Reminders
- **Local Reminders (Mobile)**:
  - On completing a pre-order checkout (in `web_checkout_screen.dart` on mobile / shared flow), check if `flutter_local_notifications` is supported.
  - Schedule local notification reminders for 7 days before harvest and 1 day before harvest, based on `harvestDays` and `createdAt`.
- **UI Banners**:
  - Render a warning/status countdown badge or card in consumer preorder details screen highlighting remaining time.

### 3. Farmer Batch Target Alerts
- **Dashboard Warning**:
  - Under `farmer_products_screen.dart` (mobile) and `web_farmer_preorders_tab.dart` (web), compute reservation rate: `(reservedQty / targetQty) * 100`.
  - If days remaining to harvest <= 5 and reservation rate < 50%, show a high-visibility warning alert banner on the product card:
    * *"⚠️ Under-reserved Alert: Only [X]% reserved with [Y] days remaining!"*
