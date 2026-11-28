import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bms_mobile_app/core/network/api_client.dart';
import 'package:bms_mobile_app/core/theme/bms_theme.dart';
import 'package:bms_mobile_app/features/auth/presentation/screens/login_screen.dart';
import 'package:bms_mobile_app/features/patient_portal/presentation/patient_shell_screen.dart';
import 'package:bms_mobile_app/features/reception_portal/presentation/receptionist_shell_screen.dart';
import 'package:bms_mobile_app/features/shell/presentation/mobile_role_router_screen.dart';
import 'package:bms_mobile_app/features/staff_portal/presentation/shells/admin_mobile_shell.dart';
import 'package:bms_mobile_app/features/staff_portal/presentation/shells/manager_mobile_shell.dart';
import 'package:bms_mobile_app/features/staff_portal/presentation/shells/staff_compact_shell.dart';
import 'package:bms_mobile_app/services/bms_auth.dart';

String _buildTestJwt({
  required int expEpochSeconds,
  String sub = 'user-001',
  String role = 'Patient',
  int roleId = 5,
}) {
  String b64(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final header = b64({'alg': 'HS256', 'typ': 'JWT'});
  final payload = b64({
    'sub': sub,
    'unique_name': 'test_user',
    'name': 'Trần Văn Kiểm Thử',
    'email': 'test@bms.med.vn',
    'role': role,
    'role_id': roleId,
    'exp': expEpochSeconds,
  });
  return '$header.$payload.signature';
}

Widget _wrapRouter() {
  return MaterialApp(
    theme: BmsTheme.lightTheme,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('vi', 'VN')],
    locale: const Locale('vi', 'VN'),
    routes: {
      '/login': (_) => const LoginScreen(),
      '/workspace': (_) => const MobileRoleRouterScreen(),
    },
    home: const MobileRoleRouterScreen(),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BmsAuth.logout();
  });

  tearDown(() async {
    await BmsAuth.logout();
  });

  test('Canonical 6-role resolution maps RoleId 1..6 and legacy 9 -> Patient', () {
    expect(BmsAuth.resolveRoleFromMap({'roleId': 1}), 'Admin');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 2}), 'Doctor');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 3}), 'Lab');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 4}), 'Receptionist');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 5}), 'Patient');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 9}), 'Patient');
    expect(BmsAuth.resolveRoleFromMap({'roleId': 6}), 'Manager');
  });

  testWidgets('Unauthenticated user is routed to LoginScreen with 6 Demo roles', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Bệnh Nhân'), findsOneWidget);
    expect(find.text('Lễ Tân'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Patient (RoleId 5) is routed to 5-tab PatientShellScreen', (
    tester,
  ) async {
    BmsAuth.accessToken = 'patient-token';
    BmsAuth.user = {
      'id': 'pat-01',
      'fullName': 'Trần Văn An',
      'roleId': 5,
      'role': 'Patient',
    };

    await tester.pumpWidget(_wrapRouter());
    await tester.pump();

    expect(find.byType(PatientShellScreen), findsOneWidget);
    final navBar = find.byType(NavigationBar);
    expect(find.descendant(of: navBar, matching: find.text('Trang chủ')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Gói XN')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Lịch khám')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Kết quả')), findsOneWidget);
    expect(find.descendant(of: navBar, matching: find.text('Tài khoản')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Doctor (2) and Lab (3) are routed to 2-tab StaffCompactShell', (
    tester,
  ) async {
    for (final entry in const [
      (id: 2, role: 'Doctor'),
      (id: 3, role: 'Lab'),
    ]) {
      BmsAuth.accessToken = 'staff-token';
      BmsAuth.user = {
        'id': 'staff-${entry.id}',
        'fullName': 'Nhân sự Y tế',
        'roleId': entry.id,
        'role': entry.role,
      };

      await tester.pumpWidget(_wrapRouter());
      await tester.pump();

      expect(find.byType(StaffCompactShell), findsOneWidget);
      expect(find.text('Lịch ca trực'), findsOneWidget);
      expect(find.text('Tài khoản'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Receptionist (RoleId 4) is routed to 3-tab ReceptionistShellScreen', (
    tester,
  ) async {
    BmsAuth.accessToken = 'recep-token';
    BmsAuth.user = {
      'id': 'rec-01',
      'fullName': 'Lễ tân Đỗ Lan Anh',
      'roleId': 4,
      'role': 'Receptionist',
    };

    await tester.pumpWidget(_wrapRouter());
    await tester.pump();

    expect(find.byType(ReceptionistShellScreen), findsOneWidget);
    expect(find.text('Quét QR'), findsOneWidget);
    expect(find.text('Lịch trực'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manager (6) -> ManagerMobileShell & Admin (1) -> AdminMobileShell', (
    tester,
  ) async {
    BmsAuth.accessToken = 'mgr-token';
    BmsAuth.user = {
      'id': 'mgr-01',
      'fullName': 'Trưởng Khoa Đỗ Lan Anh',
      'roleId': 6,
      'role': 'Manager',
    };
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    expect(find.byType(ManagerMobileShell), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    BmsAuth.accessToken = 'adm-token';
    BmsAuth.user = {
      'id': 'adm-01',
      'fullName': 'Nguyễn Quản Trị',
      'roleId': 1,
      'role': 'Admin',
    };
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    expect(find.byType(AdminMobileShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'BmsAuth.login persists session and BmsAuth.restoreSession restores & refreshes JWT',
    () async {
      final futureExp =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
          1000;
      final validJwt = _buildTestJwt(
        expEpochSeconds: futureExp,
        sub: 'doc-99',
        role: 'Doctor',
        roleId: 2,
      );

      final loginClient = MockClient((req) async {
        expect(req.url.path, '/api/auth/login');
        return http.Response(
          jsonEncode({
            'accessToken': validJwt,
            'refreshToken': 'refresh-001',
            'user': {
              'id': 'doc-99',
              'username': 'dr_nguyenminh',
              'fullName': 'BS. Nguyễn Minh',
              'roleId': 2,
              'role': 'Doctor',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final loginRes = await BmsAuth.login(
        usernameOrEmail: 'dr_nguyenminh',
        password: 'Password@123',
        client: loginClient,
      );
      expect(loginRes['success'], isTrue);
      expect(BmsAuth.userRole, 'Doctor');
      expect(ApiClient.userToken, validJwt);

      BmsAuth.accessToken = null;
      BmsAuth.refreshToken = null;
      BmsAuth.user = null;
      ApiClient.userToken = null;

      final restored = await BmsAuth.restoreSession();
      expect(restored, isTrue);
      expect(BmsAuth.accessToken, validJwt);
      expect(BmsAuth.userRole, 'Doctor');

      final pastExp =
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final expiredJwt = _buildTestJwt(
        expEpochSeconds: pastExp,
        sub: 'rec-88',
        role: 'Receptionist',
        roleId: 4,
      );
      final refreshedJwt = _buildTestJwt(
        expEpochSeconds: futureExp,
        sub: 'rec-88',
        role: 'Receptionist',
        roleId: 4,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', expiredJwt);
      await prefs.setString('refreshToken', 'refresh-valid');
      await prefs.setString(
        'user',
        jsonEncode({'id': 'rec-88', 'roleId': 4, 'role': 'Receptionist'}),
      );

      final refreshClient = MockClient((req) async {
        expect(req.url.path, '/api/auth/refresh');
        return http.Response(
          jsonEncode({
            'accessToken': refreshedJwt,
            'refreshToken': 'refresh-rotated',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final refreshedOk = await BmsAuth.restoreSession(client: refreshClient);
      expect(refreshedOk, isTrue);
      expect(BmsAuth.accessToken, refreshedJwt);
      expect(BmsAuth.userRole, 'Receptionist');
    },
  );
}
