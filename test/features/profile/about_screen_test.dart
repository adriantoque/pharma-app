import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/app_theme.dart';
import 'package:pharmaguide/features/profile/presentation/screens/about_screen.dart';

void main() {
  testWidgets('names the app and offers its licences', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PharmaGuide'), findsOneWidget);
    expect(find.text('Open source licences'), findsOneWidget);
  });
}
