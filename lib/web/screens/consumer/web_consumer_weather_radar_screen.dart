import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import 'radar/consumer_radar_view.dart';

class WebConsumerWeatherRadarScreen extends StatelessWidget {
  const WebConsumerWeatherRadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isCompact = sw < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          WebEcomHeader(
            currentIndex: -1,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onSearch: (query) {
              context.go(AppRoutes.shop, extra: {'search': query});
            },
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: const ConsumerRadarView(
                  lat: 15.9281,
                  lon: 120.3489,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
