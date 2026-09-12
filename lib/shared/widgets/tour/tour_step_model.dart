import 'package:flutter/material.dart';

enum TourCardPosition { auto, top, bottom }

enum TourSpotlightShape { roundedRectangle, circle }

/// Configuration model representing an individual step in the in-app guided tour.
class TourStepModel {
  /// The GlobalKey attached to the target widget to spotlight.
  final GlobalKey? targetKey;

  /// Header title for the tour step (e.g. "Search Fresh Farm Produce").
  final String title;

  /// Clear, user-friendly explanation of the feature.
  final String description;

  /// Badge indicator text (e.g. "1 OF 5").
  final String? badge;

  /// Optional icon displayed in the coachmark card.
  final IconData? icon;

  /// Preferred card placement relative to the spotlight target.
  final TourCardPosition preferredPosition;

  /// Spotlight cutout shape.
  final TourSpotlightShape shape;

  /// Additional padding around the target widget for the spotlight cutout.
  final EdgeInsets padding;

  /// Corner radius for roundedRectangle cutout.
  final double borderRadius;

  const TourStepModel({
    this.targetKey,
    required this.title,
    required this.description,
    this.badge,
    this.icon,
    this.preferredPosition = TourCardPosition.auto,
    this.shape = TourSpotlightShape.roundedRectangle,
    this.padding = const EdgeInsets.all(8.0),
    this.borderRadius = 16.0,
  });
}
