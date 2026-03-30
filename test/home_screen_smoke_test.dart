import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motu_flutter/views/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders without a synchronous build exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
