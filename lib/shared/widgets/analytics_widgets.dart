import 'package:flutter/material.dart';

/// Wrapper widget that automatically tracks clicks/taps
/// Usage: AnalyticsButton(onTap: () {}, child: YourWidget())
class AnalyticsButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? elementId;
  final String? elementType;

  const AnalyticsButton({
    super.key,
    required this.onTap,
    required this.child,
    this.elementId,
    this.elementType,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Execute the callback (no longer tracking clicks)
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
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.fieldId,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
    this.decoration,
  });

  @override
  State<AnalyticsTextField> createState() => _AnalyticsTextFieldState();
}

class _AnalyticsTextFieldState extends State<AnalyticsTextField> {
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
        // Keystrokes no longer tracked
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
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    // Screen views no longer tracked
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin to track screen in StatefulWidget (no longer tracks interactions)
/// Usage: class MyScreen extends StatefulWidget with AnalyticsScreenMixin
mixin AnalyticsScreenMixin<T extends StatefulWidget> on State<T> {
  String get screenName;

  @override
  void initState() {
    super.initState();
    // Screen tracking disabled
  }
}

/// Button with built-in click tracking
class TrackedElevatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? buttonId;

  const TrackedElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.buttonId,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              // No longer tracking clicks
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
    super.key,
    required this.onPressed,
    required this.child,
    this.buttonId,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              // No longer tracking clicks
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
    super.key,
    required this.onPressed,
    required this.icon,
    this.buttonId,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed == null
          ? null
          : () {
              // No longer tracking clicks
              onPressed!();
            },
      icon: icon,
    );
  }
}
