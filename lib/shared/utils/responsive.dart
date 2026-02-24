import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double webBreakpoint = 800;
  static const double tabletBreakpoint = 600;

  // Check if device is web
  static bool isWeb(BuildContext context) {
    return MediaQuery.of(context).size.width > webBreakpoint;
  }

  // Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > tabletBreakpoint && width <= webBreakpoint;
  }

  // Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= tabletBreakpoint;
  }

  // Get padding based on device type
  static EdgeInsets getPadding(BuildContext context) {
    if (isWeb(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  // Get grid columns based on device type
  static int getGridColumns(BuildContext context) {
    if (isWeb(context)) {
      return 4;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 1;
    }
  }

  // Get font size based on device type
  static double getTitleFontSize(BuildContext context) {
    if (isWeb(context)) {
      return 28;
    } else if (isTablet(context)) {
      return 22;
    } else {
      return 18;
    }
  }

  static double getSubtitleFontSize(BuildContext context) {
    if (isWeb(context)) {
      return 18;
    } else if (isTablet(context)) {
      return 16;
    } else {
      return 14;
    }
  }

  // Get spacing based on device type
  static double getSpacing(BuildContext context, {double mobile = 16, double tablet = 20, double web = 24}) {
    if (isWeb(context)) {
      return web;
    } else if (isTablet(context)) {
      return tablet;
    } else {
      return mobile;
    }
  }
}

// Extension methods for easier access
extension ResponsiveExtension on BuildContext {
  bool get isWeb => ResponsiveHelper.isWeb(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isMobile => ResponsiveHelper.isMobile(this);

  EdgeInsets get responsivePadding => ResponsiveHelper.getPadding(this);
  int get gridColumns => ResponsiveHelper.getGridColumns(this);
  double get titleFontSize => ResponsiveHelper.getTitleFontSize(this);
  double get subtitleFontSize => ResponsiveHelper.getSubtitleFontSize(this);

  double spacing({double mobile = 16, double tablet = 20, double web = 24}) {
    return ResponsiveHelper.getSpacing(this, mobile: mobile, tablet: tablet, web: web);
  }
}
