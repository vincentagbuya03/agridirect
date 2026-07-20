import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/mascot/mascot_widget.dart';

class MascotService {
  static final List<String> _farmerTips = [
    'Add detailed product descriptions to increase farmer sales by up to 30%!',
    'Keep your crop inventory updated regularly so consumers know what is fresh.',
    'Check the community hub to collaborate with other local growers.',
    'Fast shipment response times improve your marketplace ranking and reviews!',
    'Try adding high-quality photos of your harvest to attract organic buyers.'
  ];

  static final List<String> _consumerTips = [
    'Buying directly from farmers helps support local sustainable agriculture!',
    'Check out pre-orders to secure fresh organic crops before harvest season.',
    'You can filter produce by location to find the closest organic options.',
    'Write helpful reviews on your purchases to support hardworking local farmers.'
  ];

  /// Returns a context-relevant tip based on whether the user is a farmer or consumer.
  static String getRandomTip({required bool isFarmer}) {
    final list = isFarmer ? _farmerTips : _consumerTips;
    final index = Random().nextInt(list.length);
    return list[index];
  }

  /// Displays the celebration dialog with Lando cheering.
  static void showCelebration(BuildContext context, {required String message, VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MascotWidget(
          mode: MascotMode.celebration,
          expression: MascotExpression.celebrating,
          text: message,
          onClose: onDismiss,
        );
      },
    );
  }

  /// Tracks milestone displays using SharedPreferences to prevent spamming the user.
  static Future<bool> shouldShowMilestone(String milestoneId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mascot_milestone_seen_$milestoneId';
      final hasSeen = prefs.getBool(key) ?? false;
      if (!hasSeen) {
        await prefs.setBool(key, true);
        return true; // First time, show it
      }
      return false; // Already shown before
    } catch (e) {
      return true; // Fallback to show if storage fails
    }
  }
}
