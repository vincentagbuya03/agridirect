import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_button.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_step_card.dart';
import 'package:agridirect/shared/widgets/farmer/farmer_mode_switcher_capsule.dart';

void main() {
  testWidgets('FarmerButton has height >= 56px and triggers onPressed', (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerButton(
            label: 'Magpatuloy',
            icon: Icons.eco,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    final finder = find.byType(FarmerButton);
    expect(finder, findsOneWidget);
    final size = tester.getSize(finder);
    expect(size.height, greaterThanOrEqualTo(56.0));

    await tester.tap(finder);
    expect(pressed, true);
  });

  testWidgets('FarmerStepCard renders step and content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FarmerStepCard(
            stepNumber: '1',
            title: 'Numero ng Telepono',
            subtitle: 'Ilagay ang iyong mobile number',
            icon: Icons.phone_iphone,
            child: Text('Phone Input Content'),
          ),
        ),
      ),
    );

    expect(find.text('Numero ng Telepono'), findsOneWidget);
    expect(find.text('Phone Input Content'), findsOneWidget);
  });

  testWidgets('FarmerModeSwitcherCapsule triggers onSwitch callback', (tester) async {
    bool switched = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FarmerModeSwitcherCapsule(
            onSwitch: () => switched = true,
          ),
        ),
      ),
    );

    expect(find.byType(FarmerModeSwitcherCapsule), findsOneWidget);
    await tester.tap(find.byType(FarmerModeSwitcherCapsule));
    expect(switched, true);
  });
}
