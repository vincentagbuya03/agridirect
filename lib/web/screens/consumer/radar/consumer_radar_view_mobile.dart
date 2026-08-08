import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ConsumerRadarView extends StatefulWidget {
  final double lat;
  final double lon;

  const ConsumerRadarView({super.key, required this.lat, required this.lon});

  @override
  State<ConsumerRadarView> createState() => _ConsumerRadarViewState();
}

class _ConsumerRadarViewState extends State<ConsumerRadarView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final url = 'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lon}&detailLat=${widget.lat}&detailLon=${widget.lon}&zoom=10&level=surface&overlay=rain&product=ecmwf&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1';
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
        // ── Cover: Windy.com logo — AgriDirect badge ─────────────────
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AgriDirect Radar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
