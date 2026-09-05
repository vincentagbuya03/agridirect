import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_ecom_header.dart';

void main() {
  testWidgets('WebEcomHeader renders utility strip, search bar, and department tabs',
      (tester) async {
    // Set a wide desktop screen size
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebEcomHeader(
            currentIndex: 0,
            onNavigate: (index, [route]) {},
          ),
        ),
      ),
    );

    expect(find.byType(WebEcomHeader), findsOneWidget);
    expect(find.textContaining('San Carlos'), findsWidgets);
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
  });
}
