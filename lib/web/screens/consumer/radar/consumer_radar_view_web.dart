import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class ConsumerRadarView extends StatefulWidget {
  final double lat;
  final double lon;

  const ConsumerRadarView({super.key, required this.lat, required this.lon});

  @override
  State<ConsumerRadarView> createState() => _ConsumerRadarViewState();
}

class _ConsumerRadarViewState extends State<ConsumerRadarView> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'consumer-windy-iframe-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src =
            'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lon}&detailLat=${widget.lat}&detailLon=${widget.lon}&zoom=10&level=surface&overlay=rain&product=ecmwf&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1'
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%'
        ..style.display = 'block'
        ..style.pointerEvents = 'auto';

      iframe.onLoad.listen((_) {
        try {
          final dynamic doc = (iframe as dynamic).contentDocument;
          if (doc != null) {
            final style = doc.createElement('style');
            style.innerHTML =
                '#logo, .logo, #windy-logo, a[href*="windy.com"] { display: none !important; }';
            doc.head?.appendChild(style);
          }
        } catch (_) {}
      });

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: HtmlElementView(viewType: _viewType)),
        // ── Cover: Windy.com logo — AgriDirect badge ─────────────────
        Positioned(
          top: 12,
          left: 12,
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
      ],
    );
  }
}
