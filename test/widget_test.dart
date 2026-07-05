// Smoke test: the app boots and shows the Traffic Tyrants menu.

import 'package:flutter_test/flutter_test.dart';

import 'package:traffic_tyrants/main.dart';

void main() {
  testWidgets('Menu screen renders title and play button', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficTyrantsApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TRAFFIC'), findsOneWidget);
    expect(find.text('TYRANTS'), findsOneWidget);
    expect(find.text('TAP TO RIDE'), findsOneWidget);
  });
}
