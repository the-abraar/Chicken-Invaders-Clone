// Smoke test: the app boots and shows the Traffic Tyrants menu.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traffic_tyrants/main.dart';
import 'package:traffic_tyrants/game/save_data.dart';

void main() {
  testWidgets('Menu screen renders title, play and garage buttons', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await SaveData.load();

    await tester.pumpWidget(const TrafficTyrantsApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TRAFFIC'), findsOneWidget);
    expect(find.text('TYRANTS'), findsOneWidget);
    expect(find.text('START SHIFT'), findsOneWidget);
    expect(find.text('GARAGE'), findsOneWidget);
  });
}
