import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/mobile/screens/consumer/home/widgets/ecom_product_card.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('EcomProductCard renders product info and conditional discount badge', (tester) async {
    const productWithDiscount = ProductItem(
      productId: 'p-1',
      name: 'Benguet Highland Cabbage',
      farm: 'Mountain Greens Farm',
      price: '80',
      originalPrice: '100',
      discountPercent: 20,
      unit: 'kg',
      imageUrl: '',
      soldCount: 45,
      rating: '4.8',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcomProductCard(product: productWithDiscount),
        ),
      ),
    );

    expect(find.text('Benguet Highland Cabbage'), findsOneWidget);
    expect(find.text('Mountain Greens Farm'), findsOneWidget);
    expect(find.text('-20%'), findsOneWidget);
    expect(find.text('45 sold'), findsOneWidget);
  });
}
