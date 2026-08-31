import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelal_studio/app.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/storage/secure_token_storage.dart';
import 'package:path_provider/path_provider.dart';

/// PRD-mandated critical flow, the third and last named in
/// mobile/.claude/skills/flutter-testing/SKILL.md's Integration/E2E
/// section: compose -> generate -> edit -> export, end to end, against
/// this app's real widget tree and mock API (`Env.useMockApi` defaults to
/// `true` — see mobile/CLAUDE.md).
///
/// **Retries are load-bearing here, not incidental.**
/// `FakeGenerationRemoteDataSource` deliberately injects the `/generate/*`
/// typed-error taxonomy at low-but-real rates (see its own doc comment —
/// "reachable without a debugger" for a manual run) — roughly a
/// combined ~20% chance a single "Generate"/"Create graphic" tap resolves
/// to a real failure rather than success. That's exactly the right
/// behavior for the app to have, but it means a single un-retried tap in
/// this test would be a genuinely flaky assertion, not a bug in the app.
/// `tapAndRetryOnFailure` tolerates a bounded number of these synthetic
/// failures the same way a person manually driving the app would just try
/// again — it does NOT retry past the `quotaExceeded` case blindly; that
/// dialog is dismissed and counted as a retry too, since it's one of the
/// same injected outcomes.
///
/// Terminates at "Copy caption" on the Export screen, not "Save to
/// gallery"/"Share" — both of the latter can involve a real OS-level
/// permission prompt or the native Share Sheet, neither of which this
/// test can drive or dismiss, and gallery/share failure paths are already
/// covered by `export_page_test.dart`'s widget tests with a mocked
/// `ExportBloc`. Copy caption is a plain `Clipboard.setData` call with no
/// such risk, and reaching it already proves the full compose -> generate
/// -> edit -> export pipeline produced a real, navigable `CanvasScene`/
/// caption pair all the way through.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(
        (await getApplicationDocumentsDirectory()).path,
      ),
    );
    await configureDependencies();
  });

  setUp(() async {
    await getIt<SecureTokenStorage>().clear();
  });

  /// Taps [finder], settles, and — up to [maxAttempts] times total — taps
  /// again if the attempt visibly failed: either [errorBannerKey] appeared
  /// (a non-quota `ApiFailure`), or the quota-exceeded dialog appeared
  /// (dismissed via its one action button, then retried). Returns once
  /// neither failure signal is present after settling, i.e. the request
  /// must have succeeded.
  Future<void> tapAndRetryOnFailure(
    WidgetTester tester, {
    required Finder finder,
    required Key errorBannerKey,
    int maxAttempts = 8,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await tester.tap(finder);
      await tester.pumpAndSettle();

      final quotaDialogAction = find.byKey(
        const Key('app_dialog_action_button'),
      );
      if (quotaDialogAction.evaluate().isNotEmpty) {
        await tester.tap(quotaDialogAction);
        await tester.pumpAndSettle();
        continue; // quotaExceeded — one of the injected outcomes, retry.
      }

      if (find.byKey(errorBannerKey).evaluate().isEmpty) {
        return; // No failure signal visible — this attempt succeeded.
      }
    }
    fail(
      'Still failing after $maxAttempts attempts — this is far more than '
      "FakeGenerationRemoteDataSource's injected failure rates should ever "
      'produce; treat as a real regression, not synthetic flakiness.',
    );
  }

  testWidgets(
    'compose an idea, generate text, create a graphic, edit it, and reach '
    'the export screen with a copyable caption',
    (tester) async {
      await tester.pumpWidget(const KelalStudioApp());
      await tester.pumpAndSettle();

      // Log in as the pre-verified demo user — avoids the
      // EmailVerificationGate banner complicating widget-finding below
      // (it doesn't block interaction, but there's no reason to exercise
      // that gap in this particular flow test).
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'demo@kelalstudio.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Compose: enter an idea, leave language/platform at their sensible
      // defaults (Auto / Instagram — neither is asserted on, this flow
      // only cares that a caption comes back).
      expect(find.byKey(const Key('composer_idea_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('composer_idea_field')),
        'Announce our weekend flash sale on handmade leather bags',
      );

      await tapAndRetryOnFailure(
        tester,
        finder: find.byKey(const Key('composer_generate_button')),
        errorBannerKey: const Key('composer_generation_error_banner'),
      );

      // Generate: a GenerationResult landed — GenerationResultView (and
      // the "Create graphic" button beneath it) should now be showing.
      expect(
        find.byKey(const Key('composer_create_graphic_button')),
        findsOneWidget,
      );

      // "Create graphic" navigates to /canvas-editor on success — no
      // error-banner key of its own (ImageGenerationFailure shows a snack
      // bar, not a banner — see ComposerPage's listener), so this retries
      // purely on "did /canvas-editor's AppBar show up yet."
      for (var attempt = 1; attempt <= 8; attempt++) {
        final quotaDialogAction = find.byKey(
          const Key('app_dialog_action_button'),
        );
        await tester.tap(
          find.byKey(const Key('composer_create_graphic_button')),
        );
        await tester.pumpAndSettle();
        if (quotaDialogAction.evaluate().isNotEmpty) {
          await tester.tap(quotaDialogAction);
          await tester.pumpAndSettle();
          continue;
        }
        final reachedEditor = find
            .byKey(const Key('canvas_editor_continue_button'))
            .evaluate()
            .isNotEmpty;
        if (reachedEditor) break;
        if (attempt == 8) {
          fail(
            'Create graphic never reached /canvas-editor after 8 attempts '
            '— treat as a real regression, not synthetic flakiness.',
          );
        }
      }

      // Edit: reaching the editor with a real decoded CanvasScene is
      // itself the meaningful assertion for this stage (per-layer
      // drag/resize interaction is already covered by
      // canvas_editor_page_test.dart's widget tests) — Continue forwards
      // whatever scene is currently loaded.
      expect(
        find.byKey(const Key('canvas_editor_continue_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('canvas_editor_continue_button')));
      await tester.pumpAndSettle();

      // Export: the full pipeline produced a real scene + caption pair
      // that /export could render.
      expect(find.byKey(const Key('export_preview_paint')), findsOneWidget);
      expect(
        find.byKey(const Key('export_copy_caption_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('export_copy_caption_button')));
      await tester.pumpAndSettle();

      expect(find.text('Caption copied to clipboard.'), findsOneWidget);
    },
  );
}
