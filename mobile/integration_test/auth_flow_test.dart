import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelal_studio/app.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';
import 'package:path_provider/path_provider.dart';

/// PRD-mandated critical flow: sign-up -> verify -> login (see
/// mobile/.claude/skills/flutter-testing/SKILL.md's Integration/E2E
/// section). Runs against the mock API (`Env.useMockApi` defaults to
/// `true`, no extra `--dart-define` needed) — see mobile/CLAUDE.md.
///
/// Registration no longer establishes a session (PRD §11,
/// register-verification) — this test walks the real flow: register lands
/// on `CheckYourEmailPage`, which is verified via the manual paste-in
/// token field (`FakeAuthRemoteDataSource`'s deterministic
/// `fake-verify-token-for-<email>` — see `CheckYourEmailPage`'s doc
/// comment for why this is a manual field rather than a real deep link),
/// then logs in for real and reaches Compose with no verification-gate
/// banner showing (unlike before verification).
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

  testWidgets(
    'register a new account -> verify via the pasted-in code -> log in '
    'reaches Compose with no verification-gate banner showing',
    (tester) async {
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

      // Register no longer signs the user in — it navigates itself to
      // Check Your Email, naming the address it just registered.
      expect(find.byKey(const Key('check_your_email_body')), findsOneWidget);

      // Paste the deterministic fake verification token and confirm.
      await tester.enterText(
        find.byKey(const Key('check_your_email_token_field')),
        'fake-verify-token-for-$email',
      );
      await tester.tap(find.byKey(const Key('check_your_email_verify_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('check_your_email_verified_message')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('check_your_email_verified_sign_in')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login_email_field')), email);
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        password,
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Verified this time — the composer field shows, and the
      // verification-gate banner does NOT.
      expect(find.byKey(const Key('composer_idea_field')), findsOneWidget);
      expect(
        find.byKey(const Key('email_verification_gate_banner')),
        findsNothing,
      );

      // Log out through the repository (not by clearing storage directly)
      // so watchIsAuthenticated() actually emits false and AppRouter's
      // redirect: sends the app back to /login, exactly like a real
      // logout button press would.
      await getIt<AuthRepository>().logout();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    },
  );
}
