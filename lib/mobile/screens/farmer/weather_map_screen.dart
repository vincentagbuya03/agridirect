import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class WeatherMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? locationName;
  final double? temperature;
  final String? weatherDescription;

  const WeatherMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.temperature,
    this.weatherDescription,
  });

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final lat = widget.latitude.toStringAsFixed(4);
    final lon = widget.longitude.toStringAsFixed(4);
    final mapUrl = 'https://embed.windy.com/embed2.html?lat=$lat&lon=$lon&detailLat=$lat&detailLon=$lon&zoom=8&level=surface&overlay=wind&product=ecmwf&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1628))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
            // Safety timeout: if page doesn't finish loading in 3 seconds, hide spinner
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _isLoading) {
                setState(() => _isLoading = false);
              }
            });
          },
          onPageFinished: (_) {
            // Inject JS to hide the Windy logo element and branding
            _controller.runJavaScript('''
              try {
                var style = document.createElement('style');
                style.innerHTML = '#logo, .logo, #windy-logo, a[href*="windy.com"] { display: none !important; }';
                document.head.appendChild(style);
              } catch(e) {}
            ''');

            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) setState(() => _isLoading = false);
            });
          },
          onWebResourceError: (error) {
            debugPrint('WebView Error: \${error.description}');
            if (mounted && _isLoading) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(mapUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1628),
        elevation: 0,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.locationName ?? 'My Farm',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.temperature != null
                  ? '${widget.temperature!.toStringAsFixed(0)}°C · Live Weather Radar'
                  : 'Live Weather Radar',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: () => _controller.reload(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // WebView is now pushed below the AppBar and won't conflict with system/drawer views
          WebViewWidget(controller: _controller),
  
          // ── Custom Loading Overlay ───────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0B1628),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2D4A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF22C55E),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Connecting Live Radar...',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wind · Rain · Temperature layers',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(
                        width: 180,
                        child: LinearProgressIndicator(
                          color: Color(0xFF22C55E),
                          backgroundColor: Color(0xFF1E2D4A),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
