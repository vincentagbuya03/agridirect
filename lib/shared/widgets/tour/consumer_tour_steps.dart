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
      title: 'Featured Deals & Pre-Orders',
      description:
          'Discover seasonal harvest highlights, subsidized delivery programs, and lock in lower farm-gate prices.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      borderRadius: 22,
    ),
    TourStepModel(
      targetKey: cartOrAssistantKey,
      badge: '5 OF 5',
      icon: Icons.shopping_bag_rounded,
      title: 'Shopping Cart & Messages',
      description:
          'Review your farm produce basket, track dispatch to your doorstep, and chat directly with farmers in real-time.',
      preferredPosition: TourCardPosition.bottom,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 18,
    ),
  ];
}
