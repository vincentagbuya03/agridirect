import 'package:flutter/material.dart';
import 'database_sync_service.dart';

/// Mixin for widgets that need to respond to database sync events
mixin DatabaseSyncListenerMixin<T extends StatefulWidget> on State<T> {
  late DatabaseSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = DatabaseSyncService();
    _syncService.addListener(_onSyncStatusChanged);
  }

  /// Called when sync status changes (successfully or with error)
  @protected
  void onSyncStatusChanged() {}

  void _onSyncStatusChanged() {
    if (mounted) {
      onSyncStatusChanged();
    }
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStatusChanged);
    super.dispose();
  }
}

/// A wrapper widget that rebuilds when database sync completes
class DatabaseSyncListenerWidget extends StatefulWidget {
  final Widget Function(BuildContext context, bool isSyncing) builder;
  final VoidCallback? onSyncComplete;

  const DatabaseSyncListenerWidget({
    super.key,
    required this.builder,
    this.onSyncComplete,
  });

  @override
  State<DatabaseSyncListenerWidget> createState() =>
      _DatabaseSyncListenerState();
}

class _DatabaseSyncListenerState extends State<DatabaseSyncListenerWidget> {
  late DatabaseSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = DatabaseSyncService();
    _syncService.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    if (mounted) {
      setState(() {});
      if (!_syncService.isSyncing && widget.onSyncComplete != null) {
        widget.onSyncComplete!();
      }
    }
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _syncService.isSyncing);
  }
}
