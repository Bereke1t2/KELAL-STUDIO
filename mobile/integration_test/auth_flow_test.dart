import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelal_studio/app.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:path_provider/path_provider.dart';

/// PRD-mandated critical flow: sign-up -> login (see
/// mobile/.claude/skills/flutter-testing/SKILL.md's Integration/E2E
/// section). Runs against the mock API (`Env.useMockApi` defaults to
/// `true`, no extra `--dart-define` needed) — see mobile/CLAUDE.md.
///
/// This branch's `FakeAuthRemoteDataSource` starts every freshly-registered
/// account unverified (PRD §6.1), and there is no resend/deep-link
/// verification flow built yet (see `EmailVerificationGate`'s doc comment
/// and this branch's report) — so both halves of this test assert on
/// landing at the Compose screen *with the email-verification gate
/// showing*, which is what the current plumbing actually produces, rather
/// than asserting a clean unblocked landing.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mirrors lib/bootstrap.dart's two setup steps, minus `runApp` — the
    // widget itself is pumped via `tester.pumpWidget` below instead.
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(
        (await getApplicationDocumentsDirectory()).path,
      ),
    );
    await configureDependencies();
  });

  setUp(() async {
    // Start every test logged out, regardless of what a previous run on
    // this device/emulator left in secure storage.
    await getIt<SecureTokenStorage>().clear();
  });

  testWidgets('register a new account -> lands on Compose behind the '
      'email-verification gate, then logging in again with the same '
      'credentials reaches the same gated screen', (tester) async {
    await tester.pumpWidget(const KelalStudioApp());
    await tester.pumpAndSettle();

    // Starts on /login.
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);

    // Navigate to Register.
    await tester.tap(find.byKey(const Key('create_account_link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register_email_field')), findsOneWidget);

    final email =
        'integration-test-${DateTime.now().microsecondsSinceEpoch}'
        '@kelalstudio.app';
    const password = 'StrongPassw0rd!';

    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      email,
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      password,
    );
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    // AppRouter's redirect: reacts to the auth-state stream emitting
    // `true` and navigates into the shell automatically — no manual
    // navigation here, same as the existing login flow.
    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.byKey(const Key('email_verification_gate_banner')),
      findsOneWidget,
    );

    // Log out through the repository (not by clearing storage directly)
    // so `watchIsAuthenticated()` actually emits `false` and AppRouter's
    // redirect: sends the app back to /login, exactly like a real
    // logout button press would.
    await getIt<AuthRepository>().logout();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login_email_field')), email);
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      password,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
    expect(
      find.byKey(const Key('email_verification_gate_banner')),
      findsOneWidget,
    );
  });
}
