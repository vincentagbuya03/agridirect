import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/screens/consumer/web_shop_screen.dart';

void main() {
  testWidgets('WebShopScreen renders filter sidebar and product catalog toolbar',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: WebShopScreen(
          currentIndex: 1,
          onNavigate: (index) {},
        ),
      ),
    );

    expect(find.byType(WebShopScreen), findsOneWidget);
    expect(find.text('Sort by: '), findsOneWidget);
  });
}
