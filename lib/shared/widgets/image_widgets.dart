import 'package:flutter/material.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/core/supabase_config.dart';

/// A widget that displays an image with a fallback icon when the URL is null/empty.
/// Handles loading states, errors, and provides a placeholder icon.
class NetworkImageWithFallback extends StatelessWidget {
  /// The URL of the image to display
  final String? imageUrl;

  final IconData fallbackIcon;

  final double fallbackIconSize;

  final Color fallbackIconColor;

  final Color? backgroundColor;

  final double size;

  final BoxFit fit;

  final BorderRadius? borderRadius;
  const NetworkImageWithFallback({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.fallbackIconSize = 40,
    this.fallbackIconColor = Colors.grey,
    this.backgroundColor,
    this.size = 100,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  bool get _hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: _hasImageUrl
          ? ClipRRect(
              borderRadius: borderRadius ?? BorderRadius.zero,
              child: SafeNetworkImage(
                imageUrl: imageUrl!,
                fit: fit,
                width: size,
                height: size,
                placeholder: Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: SizedBox(
                      width: fallbackIconSize,
                      height: fallbackIconSize,
                      child: const AppShimmerLoader(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: Container(
                  color: backgroundColor ?? Colors.grey[200],
                  child: Icon(
                    fallbackIcon,
                    size: fallbackIconSize,
                    color: fallbackIconColor,
                  ),
                ),
              ),
            )
          : Center(
              child: Icon(
                fallbackIcon,
                size: fallbackIconSize,
                color: fallbackIconColor,
              ),
            ),
    );

    return container;
  }
}

/// A circular avatar widget that displays a profile image with a fallback icon.
class CircularAvatarWithFallback extends StatelessWidget {
  /// The URL of the avatar image
  final String? imageUrl;

  /// The icon to show when no image is available
  final IconData fallbackIcon;

  /// Radius of the circle
  final double radius;

  /// Border color
  final Color? borderColor;

  /// Border width
  final double borderWidth;

  /// Color of the fallback icon
  final Color fallbackIconColor;

  /// Background color when no image is available
  final Color? backgroundColor;

  const CircularAvatarWithFallback({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.radius = 40,
    this.borderColor,
    this.borderWidth = 2,
    this.fallbackIconColor = Colors.grey,
    this.backgroundColor,
  });

  bool get _hasImageUrl => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: _hasImageUrl
            ? SafeNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: Container(
                  color: backgroundColor ?? Colors.grey[100],
                ),
                errorWidget: Container(
                  color: backgroundColor ?? Colors.grey[200],
                  child: Icon(
                    fallbackIcon,
                    size: radius * 0.6,
                    color: fallbackIconColor,
                  ),
                ),
              )
            : Container(
                color: backgroundColor ?? Colors.grey[100],
                child: Icon(
                  fallbackIcon,
                  size: radius * 0.6,
                  color: fallbackIconColor,
                ),
              ),
      ),
    );
  }
}

/// A widget that displays a Supabase storage image safely,
/// automatically handling signed URL generation if needed.
class SafeNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final String? defaultBucket;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.defaultBucket,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  Future<String>? _urlFuture;
  String? _lastImageUrl;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initFuture();
    }
  }

  void _initFuture() {
    _lastImageUrl = widget.imageUrl;
    if (_lastImageUrl == null || _lastImageUrl!.isEmpty) {
      _urlFuture = null;
    } else {
      final rawUrl = _lastImageUrl!;
      final isHttpUrl =
          rawUrl.startsWith('http://') || rawUrl.startsWith('https://');
      final isSignedUrl = rawUrl.contains('token=');
      // Public Supabase storage URLs (/object/public/) are already accessible
      // and don't support signed URL generation — use them directly.
      final isPublicStorageUrl =
          rawUrl.contains('supabase.co/storage/v1/object/public/');
      final needsSupabaseResolution = !isHttpUrl ||
          (rawUrl.contains('supabase.co/storage/v1/object/') &&
              !isPublicStorageUrl);

      if (isSignedUrl || isPublicStorageUrl || !needsSupabaseResolution) {
        _urlFuture = Future.value(rawUrl);
      } else {
        _urlFuture = SupabaseDatabase.getSafeUrl(
          rawUrl,
          defaultBucket: widget.defaultBucket,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastImageUrl == null || _lastImageUrl!.isEmpty) {
      return widget.errorWidget ?? const Icon(Icons.error);
    }

    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data ?? '';
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ?? const SizedBox.shrink();
        }
        if (url.isEmpty) {
          return widget.errorWidget ?? const Icon(Icons.error);
        }
        return CachedNetworkImage(
          imageUrl: url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) =>
              widget.placeholder ?? const SizedBox.shrink(),
          errorWidget: (context, url, error) =>
              widget.errorWidget ?? const Icon(Icons.error),
        );
      },
    );
  }
}

/// A CircleAvatar replacement that handles Supabase storage URLs safely.
class SafeCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? child;
  final String? defaultBucket;

  const SafeCircleAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.child,
    this.defaultBucket,
  });

  @override
  Widget build(BuildContext context) {
    final centeredChild = child != null ? Center(child: child) : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? SafeNetworkImage(
                imageUrl: imageUrl,
                defaultBucket: defaultBucket,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: centeredChild,
                errorWidget: centeredChild,
              )
            : centeredChild,
      ),
    );
  }
}
