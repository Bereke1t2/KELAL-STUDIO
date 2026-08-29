import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/usecases/save_export_to_gallery_usecase.dart';
import 'package:kelal_studio/features/export/domain/usecases/share_export_usecase.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_bloc.dart';
import 'package:kelal_studio/features/export/presentation/cubit/export_overlay_seen_cubit.dart';
import 'package:kelal_studio/features/export/presentation/pages/export_page.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveExportToGalleryUseCase extends Mock
    implements SaveExportToGalleryUseCase {}

class MockShareExportUseCase extends Mock implements ShareExportUseCase {}

/// Same in-memory `Storage` seam as
/// `export_overlay_seen_cubit_test.dart`/`app_router_test.dart` — see
/// those files' doc comments.
class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

/// Taps [button] and pumps through to the bloc's resulting state.
///
/// Not a plain `tester.tap(button); await tester.pumpAndSettle();`: the
/// handler behind Save/Share awaits `RenderEngine.exportPng`, which calls
/// real `dart:ui` engine work (`Picture.toImage`/`Image.toByteData`) that
/// only resolves via genuine wall-clock event-loop processing —
/// `WidgetTester.pump()`/`pumpAndSettle()` run inside flutter_test's
/// fake-async test zone, which never lets that finish, so a bare
/// `pumpAndSettle()` right after the tap hangs until it times out (proven
/// by instrumenting `ExportBloc` with prints while debugging this: the
/// `await RenderEngine.exportPng(...)` line hadn't returned by the time
/// `pumpAndSettle` gave up). `pumpAndSettle()` is a non-starter here for a
/// second, independent reason too — `PrimaryButton`'s `isLoading` spinner
/// is indeterminate, which never stops scheduling frames on its own (see
/// `PrimaryButton.loadingValue`'s doc comment). Wrapping a trivial real
/// delay in `tester.runAsync()` gives the engine call room to actually
/// complete; the two plain `pump()`s after flush the resulting state (and
/// any transition animation) once it has.
Future<void> _tapAndAwaitRealAsyncWork(
  WidgetTester tester,
  Finder button,
) async {
  await tester.tap(button);
  await tester.pump();
  await _awaitRealAsyncWork(tester);
}

/// The `runAsync` + settle half of [_tapAndAwaitRealAsyncWork], split out
/// for tests that need to assert on the in-progress spinner (via their own
/// `tester.tap` + `tester.pump()`) before waiting for the real engine work
/// behind it to finish.
Future<void> _awaitRealAsyncWork(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
  await tester.pump();
}

Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSaveExportToGalleryUseCase saveExportToGalleryUseCase;
  late MockShareExportUseCase shareExportUseCase;
  late ui.Image background;
  late ExportPageArgs args;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    HydratedBloc.storage = _InMemoryStorage();
    saveExportToGalleryUseCase = MockSaveExportToGalleryUseCase();
    shareExportUseCase = MockShareExportUseCase();
    background = await _testImage();
    args = ExportPageArgs(
      scene: CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(4, 4),
      ),
      captionEn: 'English caption',
      captionAm: 'Amharic caption',
    );

    getIt
      ..registerFactory<ExportBloc>(
        () => ExportBloc(saveExportToGalleryUseCase, shareExportUseCase),
      )
      ..registerFactory<ExportOverlaySeenCubit>(ExportOverlaySeenCubit.new);
  });

  tearDown(() async {
    background.dispose();
    await getIt.reset();
  });

  Widget wrap() {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      home: ExportPage(args: args),
    );
  }

  testWidgets('shows the preview, caption-language toggle, and save/share/copy '
      'buttons', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export_preview_paint')), findsOneWidget);
    expect(
      find.byKey(const Key('export_caption_language_toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('export_save_button')), findsOneWidget);
    expect(find.byKey(const Key('export_share_button')), findsOneWidget);
    expect(find.byKey(const Key('export_copy_caption_button')), findsOneWidget);
  });

  group('first-run overlay', () {
    testWidgets('shows automatically the first time ExportPage is reached', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('One more step to post'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('One more step to post'), findsNothing);
    });

    testWidgets(
      'does not show again once ExportOverlaySeenCubit already recorded '
      'it as seen (show-once behavior, persisted via HydratedCubit)',
      (tester) async {
        // Pre-seed storage under HydratedCubit's default storage token
        // (runtimeType + empty id — see hydrated_bloc's own
        // `storageToken` getter) so a *fresh* ExportOverlaySeenCubit
        // instance reads back `seen: true`, exactly as would happen on a
        // real second visit to ExportPage after an app restart.
        await HydratedBloc.storage.write('ExportOverlaySeenCubit', {
          'seen': true,
        });

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('One more step to post'), findsNothing);
      },
    );

    testWidgets(
      'dismissing it via the scrim instead of tapping "Got it" still marks '
      'it seen, so it does not reappear on a later visit',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.text('One more step to post'), findsOneWidget);

        // Tap the modal barrier well above the sheet's own content rather
        // than the "Got it" button — showAppBottomSheet's
        // showModalBottomSheet defaults to isDismissible/enableDrag, so
        // this is a real, user-reachable way to close it.
        await tester.tapAt(const Offset(400, 50));
        await tester.pumpAndSettle();

        expect(find.text('One more step to post'), findsNothing);
        expect(HydratedBloc.storage.read('ExportOverlaySeenCubit'), {
          'seen': true,
        });
      },
    );
  });

  testWidgets(
    'tapping Copy caption copies the selected-language caption to the '
    'clipboard and shows a confirmation, defaulting to English',
    (tester) async {
      final copiedValues = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final callArgs = call.arguments as Map<Object?, Object?>;
            copiedValues.add(callArgs['text']! as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // Dismiss the first-run overlay first so it isn't intercepting taps.
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('export_copy_caption_button')),
      );
      await tester.tap(find.byKey(const Key('export_copy_caption_button')));
      await tester.pumpAndSettle();

      expect(copiedValues, ['English caption']);
      expect(find.text('Caption copied to clipboard.'), findsOneWidget);

      // Let the confirmation SnackBar's default ~4s duration fully elapse
      // and dismiss before continuing — pumpAndSettle() above only settles
      // its entrance animation (a SnackBar sitting statically visible on
      // its own Timer doesn't schedule new frames), so without this the
      // still-visible SnackBar physically overlaps and absorbs the tap on
      // the Copy button below.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Switching the language toggle to Amharic changes what gets copied.
      await tester.tap(find.text('AM'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('export_copy_caption_button')),
      );
      await tester.tap(find.byKey(const Key('export_copy_caption_button')));
      await tester.pumpAndSettle();

      expect(copiedValues, ['English caption', 'Amharic caption']);
    },
  );

  group('gallery save', () {
    testWidgets('tapping Save dispatches a gallery save and shows a success '
        'confirmation', (tester) async {
      when(
        () => saveExportToGalleryUseCase(any()),
      ).thenAnswer((_) async => const Result.ok(null));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('export_save_button')));
      await tester.tap(find.byKey(const Key('export_save_button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _awaitRealAsyncWork(tester);

      expect(find.text('Saved to your gallery.'), findsOneWidget);
      verify(() => saveExportToGalleryUseCase(any())).called(1);
    });

    testWidgets(
      'a permission-denied failure shows plain-language copy, not a raw '
      'exception',
      (tester) async {
        when(() => saveExportToGalleryUseCase(any())).thenAnswer(
          (_) async => const Result.err(
            ExportFailure(
              type: ExportFailureType.galleryPermissionDenied,
              message: 'denied',
            ),
          ),
        );

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('export_save_button')));
        await _tapAndAwaitRealAsyncWork(
          tester,
          find.byKey(const Key('export_save_button')),
        );

        expect(
          find.text(
            'We need permission to save to your gallery. You can grant it '
            'in your device settings.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a write failure (e.g. device storage full) shows plain-language '
      'copy',
      (tester) async {
        when(() => saveExportToGalleryUseCase(any())).thenAnswer(
          (_) async => const Result.err(
            ExportFailure(
              type: ExportFailureType.galleryWriteFailed,
              message: 'no space',
            ),
          ),
        );

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('export_save_button')));
        await _tapAndAwaitRealAsyncWork(
          tester,
          find.byKey(const Key('export_save_button')),
        );

        expect(
          find.text(
            "We couldn't save to your gallery. Check your device storage "
            'and try again.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('share', () {
    testWidgets(
      'tapping Share dispatches a share request with the selected caption '
      'and shows no snack bar on success (the OS Share Sheet itself is '
      'the confirmation)',
      (tester) async {
        when(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: 'English caption',
          ),
        ).thenAnswer((_) async => const Result.ok(null));

        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('export_share_button')),
        );
        await tester.tap(find.byKey(const Key('export_share_button')));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await _awaitRealAsyncWork(tester);

        verify(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: 'English caption',
          ),
        ).called(1);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('a share failure shows plain-language copy', (tester) async {
      when(
        () => shareExportUseCase(
          pngBytes: any(named: 'pngBytes'),
          text: any(named: 'text'),
        ),
      ).thenAnswer(
        (_) async => const Result.err(
          ExportFailure(type: ExportFailureType.shareFailed, message: 'x'),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('export_share_button')));
      await _tapAndAwaitRealAsyncWork(
        tester,
        find.byKey(const Key('export_share_button')),
      );

      expect(
        find.text("We couldn't open the share sheet. Please try again."),
        findsOneWidget,
      );
    });
  });
}
