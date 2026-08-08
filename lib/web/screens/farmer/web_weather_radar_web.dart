import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../../../shared/models/weather_model.dart';

class WebWeatherRadarScreen extends StatefulWidget {
  final WeatherData? weatherData;
  final double? farmLatitude;
  final double? farmLongitude;
  final String? farmLocationName;
  final VoidCallback onBack;
  final bool isConsumerMode;

  const WebWeatherRadarScreen({
    super.key,
    required this.weatherData,
    this.farmLatitude,
    this.farmLongitude,
    this.farmLocationName,
    required this.onBack,
    this.isConsumerMode = false,
  });

  @override
  State<WebWeatherRadarScreen> createState() => _WebWeatherRadarScreenState();
}

class _WebWeatherRadarScreenState extends State<WebWeatherRadarScreen> {
  static const Color _surfaceDark = Color(0xFF0B1628);
  static const Color _borderDark = Color(0xFF1E2D4A);

  late String _viewType;

  @override
  void initState() {
    super.initState();
    final lat = widget.farmLatitude ?? 14.5995;
    final lon = widget.farmLongitude ?? 120.9842;
    _viewType = 'windy-full-page-iframe-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
              'https://embed.windy.com/embed2.html?lat=${lat.toStringAsFixed(4)}&lon=${lon.toStringAsFixed(4)}&detailLat=${lat.toStringAsFixed(4)}&detailLon=${lon.toStringAsFixed(4)}&zoom=10&level=surface&overlay=wind&product=ecmwf&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=km%2Fh&metricTemp=%C2%B0C&radarRange=-1'
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
              style.innerHTML = '#logo, .logo, #windy-logo, a[href*="windy.com"] { display: none !important; }';
              doc.head?.appendChild(style);
            }
          } catch (_) {}
        });

        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 768;
    final data = widget.weatherData;

    final temp = data?.temperature.toStringAsFixed(0) ?? '28';
    final feelsLike = data?.feelsLike.toStringAsFixed(0) ?? '29';
    final desc = data?.description ?? 'Sunny';
    final wind = data?.windSpeed.toStringAsFixed(1) ?? '3.5';
    final humidity = data?.humidity.toStringAsFixed(0) ?? '65';
    final pressure = data?.pressure.toStringAsFixed(0) ?? '1012';
    final cloudiness = data?.cloudiness.toStringAsFixed(0) ?? '20';

    final windSpeedVal = data?.windSpeed ?? 3.5;
    final isSprayingSafe = windSpeedVal < 4.2 && !desc.toLowerCase().contains('rain');
    final sprayingStatus = isSprayingSafe ? 'SAFE' : 'CAUTION';

    final locationLabel = widget.farmLocationName ?? 'My Farm';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF070E1B),
      child: Column(
        children: [
          // ── Top Navigation Bar ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: 16,
            ),
            decoration: const BoxDecoration(
              color: _surfaceDark,
              border: Border(
                bottom: BorderSide(color: _borderDark, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (isMobile)
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                    tooltip: 'Back to Dashboard',
                  )
                else
                  OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Back to Dashboard',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: const BorderSide(color: _borderDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                SizedBox(width: isMobile ? 8 : 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isMobile
                                  ? 'Live Weather Radar'
                                  : 'Live Weather Radar & Agronomic Field Intelligence',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: isMobile ? 14 : 18,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMobile
                            ? '$locationLabel · $temp°C'
                            : '$locationLabel · $desc · $temp°C (Feels like $feelsLike°C)',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Agronomic Quick Metrics Ribbon ──────────────────────────────
          if (!widget.isConsumerMode)

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 32,
              vertical: 12,
            ),
            color: const Color(0xFF0B1628),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricPill('Spraying Safety', sprayingStatus, isSprayingSafe ? Colors.green : Colors.orange, Icons.eco_rounded),
                  const SizedBox(width: 12),
                  _buildMetricPill('Wind Speed', '$wind m/s', Colors.blue, Icons.air_rounded),
                  const SizedBox(width: 12),
                  _buildMetricPill('Humidity', '$humidity%', Colors.cyan, Icons.water_drop_outlined),
                  const SizedBox(width: 12),
                  _buildMetricPill('Cloud Cover', '$cloudiness%', Colors.amber, Icons.cloud_outlined),
                  const SizedBox(width: 12),
                  _buildMetricPill('Pressure', '$pressure hPa', Colors.purpleAccent, Icons.speed_rounded),
                ],
              ),
            ),
          ),

          // ── Full-Bleed 100% Width Interactive Radar View ───────────────
          Expanded(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // ── 100% Interactive Windy Iframe ───────────────────────
                  Positioned.fill(
                    child: HtmlElementView(viewType: _viewType),
                  ),

                  // ── Cover: Windy.com logo — AgriDirect badge ─────────────────
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Cover: Windy.com footer/attribution (bottom strip) ───
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 30,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF070E1B).withValues(alpha: 0.95),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF132238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
