import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/mobile/screens/consumer/home/widgets/ecom_flash_sale_section.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('EcomFlashSaleSection collapses to SizedBox.shrink when empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EcomFlashSaleSection(flashProducts: []),
        ),
      ),
    );

    expect(find.text('FLASH DEALS'), findsNothing);
  });

  testWidgets('EcomFlashSaleSection renders header and products when available', (tester) async {
    final products = [
      ProductItem(
        productId: 'f-1',
        name: 'Organic Highland Strawberries',
        farm: 'Benguet Berry Farm',
        price: '180',
        originalPrice: '250',
        discountPercent: 28,
        unit: 'box',
        imageUrl: '',
        isFlashSale: true,
        flashSaleEnd: DateTime.now().add(const Duration(hours: 2)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EcomFlashSaleSection(flashProducts: products),
        ),
      ),
    );

    expect(find.text('FLASH DEALS'), findsOneWidget);
    expect(find.text('Organic Highland Strawberries'), findsOneWidget);
  });
}
