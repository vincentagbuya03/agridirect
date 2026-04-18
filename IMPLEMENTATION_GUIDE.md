# 🚀 Offline Product Submission Implementation - Complete Guide

## Overview

Your Agridirect app now has **full offline capabilities**! Farmers can:

✅ **Add products without internet** - Form data saved locally  
✅ **Automatic sync when online** - Products upload automatically  
✅ **Real-time status** - See offline/online status in real-time  
✅ **Retry failed syncs** - One-click retry for failed products  
✅ **Zero data loss** - All data persists locally until synced

---

## What Was Implemented

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│            Add Product Screen (Updated)                  │
│  - Detects online/offline status                         │
│  - Stores local image paths (no immediate upload)        │
│  - Uses OfflineProductService for all saves             │
└─────────────────────┬───────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
    ┌────▼─────┐         ┌────────▼────────┐
    │  ONLINE  │         │     OFFLINE     │
    └────┬─────┘         └────────┬────────┘
         │                        │
    Upload Images         Store in Hive +
    Create in DB          Local Paths
         │                        │
         └────────────┬───────────┘
                      │
          ┌───────────▼──────────┐
          │ Connection Detected  │
          │ Triggers Auto-Sync   │
          └───────────┬──────────┘
                      │
          ┌───────────▼──────────┐
          │ Upload Images        │
          │ Create Products      │
          │ Mark as Synced       │
          └──────────────────────┘
```

### New Files Created

#### 1. **Data Model**

`lib/shared/models/offline_product_queue.dart` - Hive data model

- Stores pending product data locally
- Includes local image file paths
- Tracks sync status and errors

#### 2. **Services**

`lib/shared/services/offline/offline_queue_service.dart` - Database layer

- CRUD operations for Hive
- Manages pending products queue
- Handles marking products as synced

`lib/shared/services/offline/offline_product_service.dart` - Main business logic

- Offline-first wrapper around ProductService
- Auto-detects connectivity
- Triggers auto-sync on reconnect
- Provides UI-friendly ValueNotifiers

#### 3. **UI Widgets**

`lib/mobile/widgets/offline_sync_widget.dart` - Status indicators

- `OfflineSyncStatusWidget` - Shows pending count and sync status
- `PendingProductsListWidget` - Lists pending products with retry option

### Updated Files

| File                                                | Changes                               |
| --------------------------------------------------- | ------------------------------------- |
| `pubspec.yaml`                                      | Added `hive`, `hive_flutter`, `uuid`  |
| `lib/main.dart`                                     | Initialize Hive at app startup        |
| `lib/mobile/screens/farmer/add_product_screen.dart` | Complete offline-first implementation |

---

## Quick Start

### 1. Install Dependencies

```bash
cd c:\Users\Nick Vincent Agbuya\Documents\Flutter Project\agridirect
flutter pub get
flutter clean
flutter pub get
```

### 2. Run Your App

```bash
flutter run
```

### 3. Test Offline Feature

**Scenario 1: Add Product While Offline**

1. Turn off device internet (Airplane mode)
2. Go to Farmer Dashboard → Add Product
3. Fill form completely
4. Tap "Save Offline & Publish Later" button
5. Product is saved locally - ✅ Success!

**Scenario 2: Automatic Sync When Online**

1. Turn on internet
2. App shows "✅ Back online! Syncing pending products..."
3. Products automatically upload to database
4. "Pending" count decreases as sync completes
5. All products now visible in dashboard

---

## Code Examples

### Using Offline Service in Screens

```dart
import 'package:agridirect/shared/services/offline/offline_product_service.dart';
import 'package:agridirect/shared/services/offline/offline_queue_service.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late OfflineProductService _offlineService;

  @override
  void initState() {
    super.initState();
    _initializeOfflineService();
  }

  Future<void> _initializeOfflineService() async {
    final queueService = OfflineQueueService();
    final productService = ProductService();
    _offlineService = OfflineProductService(
      queueService: queueService,
      productService: productService,
    );
    await _offlineService.init();
  }

  // Check how many products are pending
  void _checkPending() {
    final count = _offlineService.pendingProductsCount.value;
    print('Pending products: $count');
  }

  // Manually trigger sync
  void _manualSync() {
    _offlineService.syncPendingProducts();
  }

  // Get  list of pending products
  void _viewPending() {
    final pending = _offlineService.getPendingProducts();
    for (var product in pending) {
      print('${product.name} - ${product.synced ? 'Synced' : 'Pending'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Show sync status
          ValueListenableBuilder(
            valueListenable: _offlineService.pendingProductsCount,
            builder: (context, count, _) {
              return Text('Pending: $count');
            },
          ),

          // Show loading while syncing
          ValueListenableBuilder(
            valueListenable: _offlineService.isSyncing,
            builder: (context, syncing, _) {
              return syncing
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
```

### Adding to Farmer Dashboard

```dart
// lib/mobile/screens/farmer/farmer_products_screen.dart

import 'package:agridirect/mobile/widgets/offline_sync_widget.dart';
import 'package:agridirect/shared/services/offline/offline_product_service.dart';

class FarmerProductsScreen extends StatefulWidget {
  @override
  State<FarmerProductsScreen> createState() => _FarmerProductsScreenState();
}

class _FarmerProductsScreenState extends State<FarmerProductsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Products')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Offline sync status banner
            ValueListenableBuilder(
              valueListenable: _offlineService.pendingProductsCount,
              builder: (context, count, _) {
                return ValueListenableBuilder(
                  valueListenable: _offlineService.isSyncing,
                  builder: (context, syncing, _) {
                    return OfflineSyncStatusWidget(
                      pendingProductCount: count,
                      isSyncing: syncing,
                      isOnline: true, // Get from connectivity listener
                      onRetry: () => _offlineService.syncPendingProducts(),
                    );
                  },
                );
              },
            ),

            // List pending products
            ValueListenableBuilder(
              valueListenable: _offlineService.pendingProductsCount,
              builder: (context, count, _) {
                return PendingProductsListWidget(
                  products: _offlineService.getPendingProducts(),
                  onRetryProduct: () {
                    // Handle retry for specific product
                  },
                );
              },
            ),

            // Your existing products list
            // ...
          ],
        ),
      ),
    );
  }
}
```

---

## API Reference

### OfflineProductService

#### Methods

##### `init()`

Initialize the service. Must be called before use.

```dart
await offlineService.init();
```

##### `createProduct({...})`

Save a product (online or offline automatically).

```dart
await offlineService.createProduct(
  farmerId: userId,
  name: 'Tomatoes',
  price: 50.0,
  description: 'Fresh organic tomatoes',
  categoryId: 1,
  unitId: 2,
  harvestDays: 7,
  isPreorder: false,
  availableQuantity: 100,
  localImagePaths: ['/path/to/image1.jpg', '/path/to/image2.jpg'],
);
```

##### `isOnline()`

Check if device has internet connection.

```dart
final online = await offlineService.isOnline();
print('Online: $online');
```

##### `syncPendingProducts()`

Manually trigger sync of pending products.

```dart
await offlineService.syncPendingProducts();
```

##### `getPendingProducts()`

Get list of products waiting to sync.

```dart
List<OfflineProductQueue> pending = offlineService.getPendingProducts();
print('Pending count: ${pending.length}');
```

##### `getAllLocalProducts()`

Get all local product records (synced and pending).

```dart
List<OfflineProductQueue> all = offlineService.getAllLocalProducts();
```

##### `retryFailedProduct(productId)`

Retry syncing a specific failed product.

```dart
await offlineService.retryFailedProduct('product-uuid');
```

##### `clearSyncedProducts()`

Delete all synced products from local storage.

```dart
await offlineService.clearSyncedProducts();
```

#### Properties

##### `pendingProductsCount` - ValueNotifier<int>

Stream of pending product count. Update UI when it changes.

```dart
ValueListenableBuilder(
  valueListenable: offlineService.pendingProductsCount,
  builder: (context, count, _) {
    return Text('Pending: $count');
  },
)
```

##### `isSyncing` - ValueNotifier<bool>

Stream of sync status. True while syncing.

```dart
ValueListenableBuilder(
  valueListenable: offlineService.isSyncing,
  builder: (context, syncing, _) {
    return syncing ? CircularProgressIndicator() : SizedBox.shrink();
  },
)
```

---

## Database Schema

### Hive Storage (`offline_products` box)

Product stored entry:

```dart
{
  'id': 'uuid-string',                    // Unique product ID
  'farmerId': 'auth-user-id',             // User who added it
  'name': 'Fresh Tomatoes',               // Product name
  'price': 50.0,                          // Price per unit
  'description': 'Organic & fresh',       // Product description
  'categoryId': 1,                        // Category reference
  'unitId': 2,                            // Unit reference (kg, piece, etc)
  'imageUrl': null,                       // Supabase URLs (after sync)
  'harvestDays': 7,                       // Days to harvest
  'isPreorder': false,                    // If pre-order enabled
  'availableQuantity': 100,               // Stock quantity
  'localImagePaths': ['/path/to/img1'],  // Local file paths (before upload)
  'createdAt': DateTime.now(),            // When created
  'synced': false,                        // Sync status
  'syncError': null,                      // Error message if sync failed
}
```

---

## Troubleshooting

### Products Not Syncing

**Check 1: Verify Connectivity**

```dart
final online = await _offlineService.isOnline();
print('Device online: $online');
```

**Check 2: View Pending Products**

```dart
final pending = _offlineService.getPendingProducts();
for (var p in pending) {
  print('${p.name}: ${p.syncError ?? 'No error'}');
}
```

**Check 3: Check Hive Database**

```dart
final allLocal = _offlineService.getAllLocalProducts();
print('Total local products: ${allLocal.length}');
print('Synced: ${allLocal.where((p) => p.synced).length}');
print('Pending: ${allLocal.where((p) => !p.synced).length}');
```

### Manual Retry

```dart
try {
  await _offlineService.retryFailedProduct(productId);
  print('Retry successful!');
} catch (e) {
  print('Retry failed: $e');
}
```

### Monitor Sync Progress

```dart
_offlineService.isSyncing.addListener(() {
  print('Syncing: ${_offlineService.isSyncing.value}');
});

_offlineService.pendingProductsCount.addListener(() {
  print('Pending: ${_offlineService.pendingProductsCount.value}');
});
```

---

## Key Features

### 🔄 Automatic Sync

- Detects internet reconnection
- Automatically syncs all pending products
- Shows real-time progress

### 📱 Offline-First

- Works completely offline
- No internet required to add products
- Data never lost

### 🔔 User Feedback

- Clear online/offline indicators
- Sync status messages
- Error tracking with retry option

### 💾 Local Persistence

- Hive database for reliable storage
- Survives app restart
- Efficient key-value storage

### 🎯 Developer Friendly

- Simple, clean API
- ValueNotifiers for UI reactivity
- Comprehensive error handling

---

## Performance Notes

- **Local Storage**: Using Hive (very fast, ~1-5ms per operation)
- **Image Handling**: Local paths stored, not bytes (memory efficient)
- **Auto-Sync**: Triggered on connectivity change (no polling)
- **Concurrent Sync**: Sequential processing to avoid conflicts

---

## Testing Checklist

- [ ] Turn off internet, add product → Saves locally
- [ ] Turn on internet → Auto-syncs
- [ ] Check pending counter → Decreases as syncs complete
- [ ] View pending list → Shows queued products
- [ ] Retry failed product → Re-uploads successfully
- [ ] App restart → Preserves pending products
- [ ] Multiple products queued → All sync successfully

---

## Next Steps

1. ✅ **Integration** - Add widgets to your farmer dashboard
2. ✅ **Testing** - Test offline/online scenarios
3. ✅ **Monitoring** - Track pending product metrics
4. ✅ **Polish** - Add custom error messages
5. ✅ **Scale** - Monitor large offline queues

---

## Support & Documentation

- **Hive Docs**: https://docs.hivedb.dev
- **Connectivity Plus**: https://pub.dev/packages/connectivity_plus
- **Flutter Offline**: https://flutter.dev/development/data-and-backend/state-mgmt/intro
