import 'package:flutter/material.dart';
import 'tour_step_model.dart';

/// Constructs the 5-step guided spotlight tour for Consumers.
List<TourStepModel> getConsumerTourSteps({
  GlobalKey? searchAndAddressKey,
  GlobalKey? quickChannelsKey,
  GlobalKey? featuredFarmersKey,
  GlobalKey? flashDealsKey,
  GlobalKey? cartOrAssistantKey,
}) {
  return [
    TourStepModel(
      targetKey: searchAndAddressKey,
      badge: '1 OF 5',
      icon: Icons.search_rounded,
      title: 'Find Farm-Fresh Produce',
      description:
          'Search fruits, vegetables, grains, or update your delivery address to discover harvests near your barangay.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      borderRadius: 18,
    ),
    TourStepModel(
      targetKey: quickChannelsKey,
      badge: '2 OF 5',
      icon: Icons.category_rounded,
      title: 'Explore Categories & Deals',
      description:
          'Quickly access Fresh Produce, Flash Sales, Wholesale bulk orders, and Free Shipping vouchers in one tap.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 20,
    ),
    TourStepModel(
      targetKey: featuredFarmersKey,
      badge: '3 OF 5',
      icon: Icons.agriculture_rounded,
      title: 'Meet Verified Local Farmers',
      description:
          'Browse certified agricultural producers in your province. Support real farmers and buy fresh with zero middlemen.',
      preferredPosition: TourCardPosition.top,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: flashDealsKey,
      badge: '4 OF 5',
      icon: Icons.bolt_rounded,
      title: 'Flash Deals & Pre-Orders',
      description:
          'Lock in unbeatable farm-gate prices before harvest time, or grab limited-time fresh discounts today.',
      preferredPosition: TourCardPosition.top,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: cartOrAssistantKey,
      badge: '5 OF 5',
      icon: Icons.shopping_bag_rounded,
      title: 'Track Orders & Kiko AI',
      description:
          'Review your cart, track live deliveries from farm dispatch, and chat with Kiko AI anytime for instant assistance.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.all(8),
      borderRadius: 18,
    ),
  ];
}
