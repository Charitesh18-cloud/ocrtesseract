import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suryaocr_flutter/main.dart';

void main() {
  testWidgets('Login screen loads correctly', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const TesseractOCRApp());

    // Wait for navigation and auth to settle
    await tester.pumpAndSettle();

    // Verify login screen shows expected widgets
    expect(find.text('Login'), findsOneWidget); // Update this based on actual text in your LoginScreen
    expect(find.byType(TextField), findsWidgets); // Assuming login form uses TextFields
  });
}
