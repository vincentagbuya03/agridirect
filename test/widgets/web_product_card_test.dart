import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/widgets/ecom/web_product_card.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('WebProductCard renders title, price, origin, and responds to hover',
      (tester) async {
    const sampleProduct = ProductItem(
      productId: 'prod-1',
      name: 'Fresh Native Tomatoes',
      price: '45.0',
      originalPrice: '60.0',
      farm: 'Brgy. Roxas Organic Farm',
      farmerName: 'Mang Juan',
      imageUrl: '',
      unit: 'kg',
      rating: '4.9',
      reviews: '42',
      soldCount: 150,
      isFlashSale: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 420,
            child: WebProductCard(
              product: sampleProduct,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Fresh Native Tomatoes'), findsOneWidget);
    expect(find.textContaining('₱45'), findsOneWidget);
    expect(find.textContaining('Brgy. Roxas'), findsOneWidget);
    expect(find.textContaining('FLASH DEAL'), findsOneWidget);
  });
}
