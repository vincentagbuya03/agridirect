import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/router/app_routes.dart';
import '../../widgets/web_consumer_nav_bar.dart';
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
          WebConsumerNavBar(
            currentIndex: -1,
            onNavigate: (index) => context.go(AppRoutes.webTabRoute(index)),
            onCartTap: () => context.go(AppRoutes.cart),
            margin: EdgeInsets.fromLTRB(
              isCompact ? 16 : 32,
              20,
              isCompact ? 16 : 32,
              12,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 32),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
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
