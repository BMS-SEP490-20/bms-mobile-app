import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App loads LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialRoute: '/login'));

    // Verify Login Screen displays
    expect(find.text('Đăng Nhập BMS'), findsOneWidget);
    expect(find.text('Đăng Nhập'), findsOneWidget);
    expect(find.text('Đăng Ký Tài Khoản'), findsOneWidget);
  });
}
