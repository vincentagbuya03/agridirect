import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/mobile/screens/support/kiko_ai_chat_screen.dart';

void main() {
  testWidgets('renders Kiko hero mascot and Migoo welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KikoAiChatScreen(),
      ),
    );
    await tester.pump();

    // Verify welcome greeting is present
    expect(find.textContaining("Hi, I'm Kiko, your AgriDirect AI assistant"), findsOneWidget);
    expect(find.textContaining("compare what matters"), findsOneWidget);
  });
}
