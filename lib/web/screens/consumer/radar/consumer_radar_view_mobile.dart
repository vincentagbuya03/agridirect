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
    final url =
        'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lon}&detailLat=${widget.lat}&detailLon=${widget.lon}&zoom=10&level=surface&overlay=rain&product=ecmwf&menu=&message=&calendar=now&pressure=&type=map&location=coordinates&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _controller.runJavaScript('''
              try {
                var style = document.createElement('style');
                style.innerHTML = '#logo, .logo, #windy-logo, a[href*="windy.com"], .leaflet-control-attribution { display: none !important; }';
                document.head.appendChild(style);
              } catch(e) {}
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),

          // ── Bottom Cover: Cover Windy footer attribution ───
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 24,
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
      ),
    );
  }
}
