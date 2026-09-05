import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_multi_farm_cart_group.dart';
import 'package:agridirect/web/screens/consumer/web_cart_screen.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('WebMultiFarmCartGroup renders farm header and item rows',
      (tester) async {
    final items = [
      CartItem(
        farmerId: 'f1',
        productId: 'cart-1',
        name: 'Native Red Tomatoes',
        farm: 'Brgy. Roxas Organic Farm',
        price: '45.0',
        quantity: 2,
        imageUrl: '',
        unit: 'kg',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebMultiFarmCartGroup(
            farmName: 'Brgy. Roxas Organic Farm',
            farmerId: 'f1',
            items: items,
            isSelected: true,
            onSelectAll: (val) {},
            onToggleItem: (item, val) {},
            onQuantityChanged: (item, qty) {},
            onItemRemoved: (item) {},
          ),
        ),
      ),
    );

    expect(find.text('Brgy. Roxas Organic Farm'), findsOneWidget);
    expect(find.text('Native Red Tomatoes'), findsOneWidget);
    expect(find.textContaining('Farm Voucher:'), findsOneWidget);
  });

  testWidgets('WebCartScreen builds with empty or populated cart',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: WebCartScreen(),
      ),
    );

    expect(find.byType(WebCartScreen), findsOneWidget);
  });
}
