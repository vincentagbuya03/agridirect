import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/screens/consumer/web_product_details.dart';
import 'package:agridirect/web/widgets/ecom/web_farm_storefront_card.dart';
import 'package:agridirect/shared/data/app_data.dart';

void main() {
  testWidgets('WebFarmStorefrontCard renders farmer metrics and action buttons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebFarmStorefrontCard(
            farmerName: 'Mang Juan Dizon',
            farmName: 'San Carlos Organic Growers',
            barangay: 'Brgy. Roxas',
            rating: 4.9,
            responseRate: '98%',
            soldKg: '3,450 kg',
            onChat: () {},
            onVisitStore: () {},
          ),
        ),
      ),
    );

    expect(find.text('Mang Juan Dizon • Brgy. Roxas'), findsOneWidget);
    expect(find.text('San Carlos Organic Growers'), findsOneWidget);
    expect(find.text('98%'), findsOneWidget);
    expect(find.text('Chat Farmer'), findsOneWidget);
    expect(find.text('Visit Storefront'), findsOneWidget);
  });

  testWidgets('WebProductDetails builds with sample product',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const sampleProduct = ProductItem(
      productId: 'p-1',
      name: 'Pangasinan Native Tomatoes',
      price: '45.0',
      farm: 'Brgy. Roxas Farm',
      imageUrl: '',
      unit: 'kg',
      rating: '4.9',
      reviews: '50',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: WebProductDetails(
          initialProduct: sampleProduct,
        ),
      ),
    );

    expect(find.byType(WebProductDetails), findsOneWidget);
  });
}
