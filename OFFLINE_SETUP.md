# Offline Capabilities - Getting Started Guide

## What's New?

Your farmer dashboard now supports **offline product creation**. Farmers can:

✅ Add products even without internet  
✅ Products automatically sync when online  
✅ See clear offline/online status  
✅ Retry failed syncs manually

## Installation

### 1. Install Dependencies

Run in your terminal:

```bash
cd c:\Users\Nick Vincent Agbuya\Documents\Flutter Project\agridirect
flutter pub get
```

This installs:

- `hive: ^2.2.3` - Local database
- `hive_flutter: ^1.1.0` - Flutter support
- `uuid: ^4.0.0` - Unique identifiers

### 2. Rebuild Your App

After dependencies install, rebuild:

```bash
# For Android
flutter run

# Or clean build
flutter clean
flutter pub get
flutter run
```

## Using Offline Features

### For End Users (Farmers)

1. **Go to farmer dashboard → Add Product**
2. **Fill in product details and images**
3. **Tap "Publish Product"**

**If Online:**

- Images upload immediately
- Product stored in database
- Success message shows

**If Offline:**

- Product saved locally instead
- Button shows "Save Offline & Publish Later"
- Status chip shows "Offline"
- When internet returns, sync happens automatically
- You'll see a "Syncing..." message

### For Developers

#### Initialize Offline Service

```dart
import 'package:agridirect/shared/services/offline/offline_product_service.dart';
import 'package:agridirect/shared/services/offline/offline_queue_service.dart';

late OfflineProductService _offlineService;

@override
void initState() {
  super.initState();
  _initializeOffline();
}

Future<void> _initializeOffline() async {
  final queueService = OfflineQueueService();
  final productService = ProductService();
  _offlineService = OfflineProductService(
    queueService: queueService,
    productService: productService,
  );
  await _offlineService.init();
}
```

#### Listen to Pending Products

```dart
ValueNotifier<int> pendingCount = _offlineService.pendingProductsCount;
ValueNotifier<bool> syncing = _offlineService.isSyncing;

// Use in UI
ValueListenableBuilder(
  valueListenable: pendingCount,
  builder: (context, count, _) {
    return Text('Pending: $count products');
  },
)
```

#### Manually Trigger Sync

```dart
await _offlineService.syncPendingProducts();
```

#### Get Pending Products

```dart
List<OfflineProductQueue> pending = _offlineService.getPendingProducts();

// Retry a specific failed product
await _offlineService.retryFailedProduct(productId);
```

## File Structure

```
lib/
├── shared/
│   ├── models/
│   │   ├── offline_product_queue.dart       ← Data model
│   │   └── offline_product_queue.g.dart     ← Auto-generated
│   └── services/
│       └── offline/
│           ├── offline_queue_service.dart   ← Hive operations
│           └── offline_product_service.dart ← Main service
├── mobile/
│   ├── screens/
│   │   └── farmer/
│   │       └── add_product_screen.dart      ← Updated with offline
│   └── widgets/
│       └── offline_sync_widget.dart         ← UI components
└── main.dart                                 ← Hive init added

pubspec.yaml                                  ← Dependencies added
```

## How It Works Under the Hood

### Offline Flow

1. **User submits form offline**

   ```
   Form Data + Local Image Paths → Stored in Hive
   ```

2. **No immediate upload needed**

   ```
   Images stay on device (not uploaded yet)
   Product record stored locally
   ```

3. **When internet returns**
   ```
   System detects connectivity → Triggers auto-sync
   For each pending product:
     - Upload images to Supabase Storage
     - Create product record in database
     - Mark as synced
     - Remove from offline queue
   ```

### Data Storage

**Hive Box:** `offline_products`

Each pending product stores:

- Product details (name, price, description, etc.)
- **Local image file paths** (not URLs yet)
- Sync status (pending/synced)
- Creation timestamp
- Error message (if sync failed)

## Troubleshooting

### Products Not Syncing

**Check connectivity:**

```dart
final isOnline = await _offlineService.isOnline();
print('Online: $isOnline');
```

**Manually retry:**

```dart
await _offlineService.syncPendingProducts();
```

### View All Pending Products

```dart
List<OfflineProductQueue> all = _offlineService.getAllLocalProducts();
for (var p in all) {
  print('${p.name} - ${p.synced ? 'Synced' : 'Pending'}');
  if (p.syncError != null) print('Error: ${p.syncError}');
}
```

### Clear Synced Products

```dart
await _offlineService.clearSyncedProducts();
```

## Key Classes

### OfflineProductService

Main service for offline product management.

**Methods:**

- `init()` - Initialize service
- `createProduct()` - Add product (online or offline)
- `isOnline()` - Check connectivity
- `syncPendingProducts()` - Sync all pending
- `retryFailedProduct(id)` - Retry specific product
- `getPendingProducts()` - Get pending list
- `getAllLocalProducts()` - Get all local products
- `clearSyncedProducts()` - Delete synced records

**Streams:**

- `pendingProductsCount` - ValueNotifier<int> for UI updates
- `isSyncing` - ValueNotifier<bool> for loading state

### OfflineQueueService

Low-level Hive database operations.

**Methods:**

- `init()` - Open Hive box
- `addProductToQueue()` - Save product locally
- `getPendingProducts()` - Get unsync'd products
- `markAsSynced(id)` - Mark synced
- `setSyncError(id, error)` - Record error
- `removeProduct(id)` - Delete product
- `clearAllSyncedProducts()` - Bulk delete

### OfflineSyncStatusWidget

Shows sync status banner with pending count.

### PendingProductsListWidget

Lists all pending products with retry buttons.

## Next Steps

1. ✅ **Install dependencies** - `flutter pub get`
2. ✅ **Rebuild app** - `flutter run`
3. ✅ **Test offline** - Turn off internet, add product
4. ✅ **Test sync** - Turn on internet, watch auto-sync
5. ✅ **Integrate widgets** - Add to farmer dashboard
6. ✅ **Monitor** - Check logs and pending count

## Support

For issues, check:

- Terminal output for debug logs (search for 🔵 ✅ ❌)
- Hive database integrity with `_offlineService.getAllLocalProducts()`
- Internet connectivity with `_offlineService.isOnline()`

## Files Changed Summary

| File                               | Change                       |
| ---------------------------------- | ---------------------------- |
| pubspec.yaml                       | Added 3 packages             |
| lib/main.dart                      | +Hive initialization         |
| add_product_screen.dart            | Offline-first implementation |
| (New) offline_product_queue.dart   | Data model                   |
| (New) offline_queue_service.dart   | Hive operations              |
| (New) offline_product_service.dart | Main service                 |
| (New) offline_sync_widget.dart     | UI widgets                   |
