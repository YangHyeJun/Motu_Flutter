import 'package:flutter_test/flutter_test.dart';
import 'package:motu_flutter/app.dart';

void main() {
  testWidgets('splash transitions to home screen', (tester) async {
    await tester.pumpWidget(const MotuApp());

    expect(find.text('모두투자'), findsOneWidget);
    expect(find.text('EVERYONE INVEST'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.text('수익률부터 중요한 건 꾸준함과 투자 습관입니다.'), findsOneWidget);
    expect(find.text('AI의 오늘의 투자 조언'), findsOneWidget);
  });
}
