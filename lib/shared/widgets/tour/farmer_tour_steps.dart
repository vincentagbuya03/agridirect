import 'package:flutter/material.dart';
import 'tour_step_model.dart';

/// Constructs the 5-step guided spotlight tour for Farmers.
List<TourStepModel> getFarmerTourSteps({
  GlobalKey? performanceBentoKey,
  GlobalKey? weatherAiKey,
  GlobalKey? quickOpsKey,
  GlobalKey? salesAnalyticsKey,
  GlobalKey? headerActionsKey,
}) {
  return [
    TourStepModel(
      targetKey: performanceBentoKey,
      badge: '1 OF 5',
      icon: Icons.insights_rounded,
      title: 'Farm Performance & Sales',
      description:
          'Monitor your total farm revenue, active listings, customer followers, and yearly sales trends at a glance.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: weatherAiKey,
      badge: '2 OF 5',
      icon: Icons.radar_rounded,
      title: 'Satellite Weather & AI Tips',
      description:
          'Protect your harvest with live rain radar, typhoon advisories, and AI recommendations from Kiko.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: quickOpsKey,
      badge: '3 OF 5',
      icon: Icons.add_circle_outline_rounded,
      title: 'Post Harvests & Manage Stock',
      description:
          'Quickly add new produce with pictures, set price per kilo, update available inventory, and create vouchers.',
      preferredPosition: TourCardPosition.top,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: salesAnalyticsKey,
      badge: '4 OF 5',
      icon: Icons.bar_chart_rounded,
      title: 'Sales Trends & History',
      description:
          'Analyze weekly and monthly revenue charts to plan future harvest yields and optimize produce pricing.',
      preferredPosition: TourCardPosition.top,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: headerActionsKey,
      badge: '5 OF 5',
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Buyer Messages & Alerts',
      description:
          'Chat directly with interested buyers, negotiate bulk orders, and receive instant alerts when items are ordered.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 18,
    ),
  ];
}
