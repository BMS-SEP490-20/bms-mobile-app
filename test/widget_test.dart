import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bms_mobile_app/main.dart' as app;
import 'package:bms_mobile_app/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Vietnamese login route has Material localizations', (
    tester,
  ) async {
    await tester.pumpWidget(const app.BmsMobileApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    final context = tester.element(find.byType(LoginScreen));
    expect(Localizations.localeOf(context), const Locale('vi', 'VN'));
    expect(MaterialLocalizations.of(context).okButtonLabel, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Startup with an empty saved token opens login', (tester) async {
    SharedPreferences.setMockInitialValues({'token': ''});
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
