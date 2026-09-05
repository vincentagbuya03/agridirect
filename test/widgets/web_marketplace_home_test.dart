import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/screens/consumer/web_marketplace_home.dart';

void main() {
  testWidgets('WebMarketplaceHome builds with modern bento and flash deals',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: WebMarketplaceHome(
          currentIndex: 0,
          onNavigate: (index, [route]) {},
        ),
      ),
    );

    expect(find.byType(WebMarketplaceHome), findsOneWidget);
    expect(find.textContaining('Explore by Harvest Category'), findsOneWidget);
    expect(find.textContaining('Community & Transparency'), findsOneWidget);
  });
}
