import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tour_step_model.dart';
import 'spotlight_tour_overlay.dart';

/// Manages showing, hiding, and persisting in-app guided spotlight tours.
class SpotlightTourController {
  static const String consumerTourKey = 'agridirect_consumer_tour_completed';
  static const String farmerTourKey = 'agridirect_farmer_tour_completed';

  static OverlayEntry? _activeOverlay;

  /// Checks if the tour was previously completed for the given preference key.
  static Future<bool> isTourCompleted(String prefKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Resets the tour status so it can trigger again.
  static Future<void> resetTourStatus(String prefKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, false);
    } catch (_) {
      // Ignored
    }
  }

  /// Marks the tour as completed.
  static Future<void> markTourCompleted(String prefKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
    } catch (_) {
      // Ignored
    }
  }

  /// Launches the spotlight tour overlay on top of the current screen.
  /// If [force] is false and the tour was already completed, this call is a no-op.
  static Future<bool> startTour(
    BuildContext context, {
    required List<TourStepModel> steps,
    required String prefKey,
    bool force = false,
    VoidCallback? onCompleted,
  }) async {
    if (steps.isEmpty) return false;

    // Check completion status if not forced
    if (!force) {
      final completed = await isTourCompleted(prefKey);
      if (completed) return false;
    }

    // Dismiss existing tour if already active
    dismissActiveTour();

    if (!context.mounted) return false;
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return false;

    late OverlayEntry entry;

    void cleanup() {
      if (_activeOverlay == entry) {
        entry.remove();
        _activeOverlay = null;
      }
      markTourCompleted(prefKey);
      onCompleted?.call();
    }

    entry = OverlayEntry(
      builder: (ctx) => SpotlightTourOverlay(
        steps: steps,
        onFinish: cleanup,
        onSkip: cleanup,
      ),
    );

    _activeOverlay = entry;
    overlayState.insert(entry);
    return true;
  }

  /// Dismisses any currently open tour overlay.
  static void dismissActiveTour() {
    _activeOverlay?.remove();
    _activeOverlay = null;
  }
}
