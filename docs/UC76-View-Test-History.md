# UC76 — View Test History (Mobile)

I3-087 / BR-232; backend I3-085 / BR-230; web I3-086 / BR-231.

## Navigation and data

Register `/patient/test-history` in `lib/main.dart`, add a landing entry, and direct the patient homepage's My results action/tab to that route. The screen guards the active session and clinical/Patient roles before fetching; server authorization remains authoritative. It reads raw canonical role names or IDs 1/2/3/4/9 locally because the older shared auth role helper uses a different numeric mapping. Other modules' auth behavior is unchanged.

Use AppColors, Material cards, existing typography and full-width scrollable content. Search debounces 300 ms; patient/date filters, clear, count, previous/next, refresh, loaders, empty/error/retry and a separate detail route are provided. Generation checks reject obsolete search responses. Dates display UTC+7 with missing dates left unknown. Detail values are aligned right; reference/flag text comes from the server.

The repository calls `/api/test-history` with the active bearer token, never passes account identity for authorization, and never uses the shared client's demo-success fallback. HTTP/auth/network/format errors fail visibly. Responses received after the session changes are rejected. Clinical values are not stored in preferences or passed in route arguments. Detail is loaded again by ID; unavailable models additionally discard injected items/conclusion.

BR-PAT-01: only server-scoped results are returned. Values/conclusion require approved, signed, non-rerun results and the matching completed/stored sample; otherwise show Đang phân tích. Dependent placeholders grant no access. No PDF/sharing/demo endpoint is called.

## API address

Default: the existing `ApiClient.baseUrl` (`http://10.0.2.2:5000/api` for Android emulator). Override for another environment:

```powershell
flutter run --dart-define=BMS_API_BASE_URL=https://your-server.example/api
```

Use the actual backend address; localhost on a physical device means that device. UC76 does not silently try other hosts with a bearer token. The main Android manifest declares INTERNET for API access across build modes, following [Flutter networking configuration](https://docs.flutter.dev/data-and-backend/networking). No broad cleartext exception or certificate bypass is added.

## Minimal integration fixes

Full app compilation exposed six existing invalid Flutter API references in process_payment_screen.dart. Replace EdgeInsets.bottom with EdgeInsets.only(bottom: ...) and MainAxisAlignment.between with spaceBetween. No payment behavior is redesigned. `flutter pub get` restores qr/qr_flutter already declared in pubspec; no dependency is newly declared and no ignored lock/cache/build file is committed.

## Verification

- Targeted `flutter analyze --no-pub` on UC76 models/repository/screen/tests and main/home integration: no issues.
- Including the existing payment screen reports two pre-existing Radio groupValue/onChanged deprecation infos (no compile error); these unchanged APIs are outside UC76's minimal compile fixes.
- `flutter test --no-pub test/uc76_test_history_test.dart test/widget_test.dart`: 9 tests pass (8 UC76 transport/model/widget tests and existing app smoke test).
- `flutter build apk --debug --no-pub`: succeeds; debug artifact at `build/app/outputs/flutter-apk/app-debug.apk` (ignored, not committed).
- Tests cover canonical roles, bearer/filters, HTTP and network failure without fake success, changed sessions, unavailable-detail redaction, signed values/unknown times, pending UI and logged-out no-fetch behavior.

These are automated widget/transport checks, not an emulator walkthrough or production deployment. Before merge, use an authenticated test account against the backend to verify date/search/paging, denied roles, ownership and revoked/unsigned data on the target device. Existing unrelated demo screens remain unchanged.
