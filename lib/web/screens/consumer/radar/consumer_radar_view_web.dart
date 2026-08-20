import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:google_fonts/google_fonts.dart';

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
            'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lon}&detailLat=${widget.lat}&detailLon=${widget.lon}&zoom=10&level=surface&overlay=rain&product=ecmwf&menu=&message=&calendar=now&pressure=&type=map&location=coordinates&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1'
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
                '#logo, .logo, #windy-logo, a[href*="windy.com"], #embed-zoom, .leaflet-control-attribution { display: none !important; }';
            doc.head?.appendChild(style);
          }
        } catch (_) {}
      });

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Stack(
      children: [
        Positioned.fill(child: HtmlElementView(viewType: _viewType)),

        // ── Direct Center Cover: Sits exactly over the Windy.com logo/marker ──
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: isMobile ? 6 : 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AgriDirect Radar',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4ADE80),
                          fontSize: isMobile ? 8.5 : 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom Cover: Cover Windy footer attribution ───
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 26,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF070E1B).withValues(alpha: 0.95),
                    const Color(0xFF070E1B).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
