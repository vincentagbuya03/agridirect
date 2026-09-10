import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/router/app_routes.dart';
import '../../widgets/ecom/web_ecom_header.dart';
import '../../widgets/ecom/web_customer_orders_content.dart';
import '../../widgets/web_footer.dart';

/// Full-page dedicated Web Orders & Deliveries Screen
class WebCustomerOrdersScreen extends StatelessWidget {
  final int initialTab;
  final String? initialOrderId;

  const WebCustomerOrdersScreen({
    super.key,
    this.initialTab = 0,
    this.initialOrderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ─── Header ───
          WebEcomHeader(
            currentIndex: 3,
            onNavigate: (index, [route]) {
              if (route != null) {
                context.go(route);
              } else {
                context.go(AppRoutes.webTabRoute(index));
              }
            },
            onSearch: (query) {
              if (query.trim().isNotEmpty) {
                context.go('/shop?q=${Uri.encodeComponent(query.trim())}');
              }
            },
          ),

          // ─── Scrollable Orders Body ───
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: WebCustomerOrdersContent(
                          initialTabIndex: initialTab,
                          initialOrderId: initialOrderId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const AgriDirectWebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
