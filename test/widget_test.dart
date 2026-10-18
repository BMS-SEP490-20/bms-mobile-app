import 'package:flutter_test/flutter_test.dart';
import 'package:bms_mobile_app/main.dart';

void main() {
  testWidgets('BMS Mobile App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BmsMobileApp());
    expect(find.text('BMS Health'), findsOneWidget);
  });
}
