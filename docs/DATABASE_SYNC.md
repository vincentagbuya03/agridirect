# Database Sync Service

Automatic database synchronization system that keeps your app data in sync with the backend database.

## Features

- ✅ Automatic periodic syncing
- ✅ Background profile updates
- ✅ Image URL syncing
- ✅ Registration status updates
- ✅ Customizable sync intervals
- ✅ Error handling and retry
- ✅ Change notifications for UI updates

## How It Works

The sync system runs periodic timers that fetch fresh data from the database at configured intervals:

- **Profile Sync**: Every 5 minutes (user info, avatar, name, email, phone)
- **Image Sync**: Every 10 minutes (farmer images, product images)
- **Registration Sync**: Every 3 minutes (farmer registration status, documents)

## Usage

### 1. Basic Setup (Automatic)

The sync service starts automatically when the app initializes in `main.dart`:

```dart
// Already configured in main.dart
DatabaseSyncService().startAutoSync(
  syncProfiles: true,
  syncImages: true,
  syncRegistrations: true,
);
```

### 2. Manual Sync

Trigger a manual sync whenever needed:

```dart
final syncService = DatabaseSyncService();

// Sync everything
await syncService.syncAll();

// Sync specific data
await syncService.syncProfiles();
await syncService.syncImages();
await syncService.syncRegistrations();
```

### 3. Listen to Sync Changes

**Option A: Using Mixin (for StatefulWidget)**

```dart
class MyProfileScreen extends StatefulWidget {
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with DatabaseSyncListenerMixin {
  @override
  void onSyncStatusChanged() {
    // Called whenever sync status changes
    setState(() {
      // Rebuild UI with fresh data
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Profile synced!'),
      ),
    );
  }
}
```

**Option B: Using DatabaseSyncListenerWidget**

```dart
@override
Widget build(BuildContext context) {
  return DatabaseSyncListenerWidget(
    builder: (context, isSyncing) => Scaffold(
      body: Stack(
        children: [
          // Your content
          if (isSyncing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    ),
    onSyncComplete: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data synced!')),
      );
    },
  );
}
```

**Option C: Direct Listener**

```dart
@override
void initState() {
  super.initState();
  DatabaseSyncService().addListener(_onSync);
}

void _onSync() {
  if (mounted) {
    setState(() {});
  }
}

@override
void dispose() {
  DatabaseSyncService().removeListener(_onSync);
  super.dispose();
}
```

### 4. Check Sync Status

```dart
final syncService = DatabaseSyncService();

// Check if currently syncing
if (syncService.isSyncing) {
  print('Syncing in progress...');
}

// Get last sync time
final lastSync = syncService.lastProfileSync;
if (lastSync != null) {
  print('Last synced: $lastSync');
}

// Check for errors
if (syncService.lastSyncError != null) {
  print('Sync error: ${syncService.lastSyncError}');
}
```

### 5. Customize Sync Intervals

Edit `database_sync_service.dart` to change intervals:

```dart
final Duration _profileSyncInterval = const Duration(minutes: 5);
final Duration _imageSyncInterval = const Duration(minutes: 10);
final Duration _registrationSyncInterval = const Duration(minutes: 3);
```

## Use Cases

### Auto-Updating Avatars

When a user updates their avatar, it's automatically synced every 10 minutes. Use the `CircularAvatarWithFallback` widget with the synced image URL.

### Farmer Registration Status

Track registration approvals automatically. The sync service checks registration status every 3 minutes and notifies listeners when it changes.

### Fresh Product Images

Product images are synced every 10 minutes, ensuring listings show the latest photos without manual refresh.

### Profile Completeness

User profile info is refreshed every 5 minutes, so name, email, and phone changes are reflected throughout the app.

## Best Practices

1. **Don't over-sync**: The default intervals are optimized. Only customize if needed.
2. **Handle offline gracefully**: Check `lastSyncError` for network issues.
3. **Use listeners, not polling**: Let the sync service notify UI, don't constantly fetch.
4. **Unsubscribe on dispose**: Always remove listeners in `dispose()` to prevent memory leaks.
5. **Manual sync for critical updates**: Use `syncAll()` after important actions like registration approval.

## Integration Example

Here's a complete profile screen that syncs automatically:

```dart
class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with DatabaseSyncListenerMixin {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    // Load from database (will be auto-synced)
  }

  @override
  void onSyncStatusChanged() {
    // Refresh UI when sync completes
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Center(
        child: CircularAvatarWithFallback(
          imageUrl: _avatarUrl,
          fallbackIcon: Icons.person,
          radius: 60,
        ),
      ),
    );
  }
}
```

## Troubleshooting

**Images still show default icon?**

- Check that `image_url` or `avatar_url` fields exist in your database
- Verify the user has actually uploaded an image
- Check `lastSyncError` for sync failures

**Sync not running?**

- Ensure `isLoggedIn` returns true in `AuthService`
- Check debug logs for "Database sync service started"
- Verify the sync function isn't catching exceptions silently

**High data usage?**

- Increase sync intervals in `database_sync_service.dart`
- Reduce the number of fields being fetched in each sync

## Architecture

```
main.dart (initialization)
    ↓
DatabaseSyncService (manages sync timers)
    ↓
┌─────────────────────────────────┐
│ Periodic Sync (Timer.periodic)  │
├─────────────────────────────────┤
│ - syncProfiles()                │
│ - syncImages()                  │
│ - syncRegistrations()           │
└─────────────────────────────────┘
    ↓
Listeners notified (ChangeNotifier)
    ↓
UI rebuilds with fresh data
```

## API Reference

### DatabaseSyncService

```dart
// Lifecycle
void startAutoSync({
  bool syncProfiles = true,
  bool syncImages = true,
  bool syncRegistrations = true,
})

void stopAutoSync()

// Manual sync
Future<void> syncAll()
Future<void> syncProfiles()
Future<void> syncImages()
Future<void> syncRegistrations()

// State checks
bool get isSyncing
String? get lastSyncError
DateTime? get lastProfileSync
DateTime? get lastImageSync
DateTime? get lastRegistrationSync

// Utilities
void clearSyncState()
```

---

**Automatically keeps your app data fresh without user intervention! 🔄**
