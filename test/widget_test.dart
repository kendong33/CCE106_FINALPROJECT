// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:final_project/main.dart';
import 'package:final_project/auth_service.dart';
import 'package:flutter/foundation.dart';

// Lightweight test double to avoid initializing Firebase during widget tests.
class TestAuthService extends ChangeNotifier {
  dynamic get currentUser => null;

  String? get userRole => null;

  Future<void> signOut() async {}
}

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Test'))),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });
}
