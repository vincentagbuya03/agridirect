import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';

/// Wrapper widget that automatically tracks clicks/taps
/// Usage: AnalyticsButton(onTap: () {}, child: YourWidget())
class AnalyticsButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? elementId;
  final String? elementType;

  const AnalyticsButton({
    Key? key,
    required this.onTap,
    required this.child,
    this.elementId,
    this.elementType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Track the click
        final userId = AuthService().userId;
        if (userId.isNotEmpty) {
          AnalyticsService().trackClick(
            userId: userId,
            elementId: elementId,
            elementType: elementType ?? 'button',
          );
        }

        // Execute the callback
        onTap?.call();
      },
      child: child,
    );
  }
}

/// TextField that tracks keystrokes
class AnalyticsTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? fieldId;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final InputDecoration? decoration;

  const AnalyticsTextField({
    Key? key,
    this.controller,
    this.labelText,
    this.hintText,
    this.fieldId,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
    this.decoration,
  }) : super(key: key);

  @override
  State<AnalyticsTextField> createState() => _AnalyticsTextFieldState();
}

class _AnalyticsTextFieldState extends State<AnalyticsTextField> {
  int _previousLength = 0;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
          ),
      onChanged: (value) {
        // Track keystrokes (difference in length)
        final currentLength = value.length;
        final keystrokeCount = (currentLength - _previousLength).abs();

        if (keystrokeCount > 0) {
          final userId = AuthService().userId;
          if (userId.isNotEmpty) {
            AnalyticsService().trackKeystrokes(
              userId: userId,
              count: keystrokeCount,
              elementId: widget.fieldId,
            );
          }
        }

        _previousLength = currentLength;
        widget.onChanged?.call(value);
      },
    );
  }
}

/// Screen wrapper that tracks screen views
class AnalyticsScreen extends StatefulWidget {
  final String screenName;
  final Widget child;

  const AnalyticsScreen({
    Key? key,
    required this.screenName,
    required this.child,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    _trackScreen();
  }

  void _trackScreen() {
    final userId = AuthService().userId;
    if (userId.isNotEmpty) {
      AnalyticsService().trackScreen(
        userId: userId,
        screenName: widget.screenName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin to automatically track screen in StatefulWidget
/// Usage: class MyScreen extends StatefulWidget with AnalyticsScreenMixin
mixin AnalyticsScreenMixin<T extends StatefulWidget> on State<T> {
  String get screenName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = AuthService().userId;
      if (userId.isNotEmpty) {
        AnalyticsService().trackScreen(userId: userId, screenName: screenName);
      }
    });
  }
}

/// Button with built-in click tracking
class TrackedElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? buttonId;

  const TrackedElevatedButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.buttonId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              // Track click
              final userId = AuthService().userId;
              if (userId.isNotEmpty) {
                AnalyticsService().trackClick(
                  userId: userId,
                  elementId: buttonId,
                  elementType: 'elevated_button',
                );
              }
              onPressed!();
            },
      child: child,
    );
  }
}

/// TextButton with built-in click tracking
class TrackedTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? buttonId;

  const TrackedTextButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.buttonId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              // Track click
              final userId = AuthService().userId;
              if (userId.isNotEmpty) {
                AnalyticsService().trackClick(
                  userId: userId,
                  elementId: buttonId,
                  elementType: 'text_button',
                );
              }
              onPressed!();
            },
      child: child,
    );
  }
}

/// IconButton with built-in click tracking
class TrackedIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? buttonId;

  const TrackedIconButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.buttonId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed == null
          ? null
          : () {
              // Track click
              final userId = AuthService().userId;
              if (userId.isNotEmpty) {
                AnalyticsService().trackClick(
                  userId: userId,
                  elementId: buttonId,
                  elementType: 'icon_button',
                );
              }
              onPressed!();
            },
      icon: icon,
    );
  }
}
