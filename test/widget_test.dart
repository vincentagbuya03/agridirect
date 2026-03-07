

import 'package:argidirect/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgriDirect app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(AgriDirectApp());


    expect(find.text('AgriDirect'), findsWidgets);
  });
}
