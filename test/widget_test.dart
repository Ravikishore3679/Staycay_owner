// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/test.dart';

import 'package:heavenrock_registry/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
  });

  testWidgets('Guest House Registry loads dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GuestHouseRegistryApp());

    expect(find.text('Guest House Registry'), findsOneWidget);
    expect(find.text('Revenue vs Expenditure'), findsOneWidget);
  });
}
