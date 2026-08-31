import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/core/widgets/skeleton_loader.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/update_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/upload_brand_logo_usecase.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_bloc.dart';
import 'package:kelal_studio/features/brand_kit/presentation/pages/brand_kit_page.dart';
import 'package:mocktail/mocktail.dart';

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

class MockUpdateBrandKitUseCase extends Mock implements UpdateBrandKitUseCase {}

class MockUploadBrandLogoUseCase extends Mock
    implements UploadBrandLogoUseCase {}

void main() {
  late MockGetBrandKitUseCase getBrandKitUseCase;
  late MockUpdateBrandKitUseCase updateBrandKitUseCase;
  late MockUploadBrandLogoUseCase uploadBrandLogoUseCase;

  final brandKit = BrandKit(
    id: 'brand-kit-1',
    brandName: 'Demo Business',
    logoAssetId: null,
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: 'Friendly',
    contactInfo: 'hello@demo.app',
    updatedAt: DateTime.utc(2026),
  );

  setUpAll(() {
    registerFallbackValue(brandKit);
  });

  setUp(() {
    getBrandKitUseCase = MockGetBrandKitUseCase();
    updateBrandKitUseCase = MockUpdateBrandKitUseCase();
    uploadBrandLogoUseCase = MockUploadBrandLogoUseCase();
    getIt.registerFactory<BrandKitBloc>(
      () => BrandKitBloc(
        getBrandKitUseCase,
        updateBrandKitUseCase,
        uploadBrandLogoUseCase,
      ),
    );
  });

  tearDown(() async {
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
      home: const BrandKitPage(),
    );
  }

  testWidgets(
    'shows a skeleton placeholder form while the brand kit is loading',
    (tester) async {
      when(getBrandKitUseCase.call).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Result.ok(brandKit);
      });

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'once loaded, shows the form pre-filled with the brand kit fields',
    (tester) async {
      when(
        getBrandKitUseCase.call,
      ).thenAnswer((_) async => Result.ok(brandKit));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Demo Business'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Friendly'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'hello@demo.app'), findsOneWidget);
      expect(find.widgetWithText(TextField, '#855312'), findsOneWidget);
      expect(find.widgetWithText(TextField, '#C6821F'), findsOneWidget);
      expect(find.byKey(const Key('brand_kit_save_button')), findsOneWidget);
    },
  );

  testWidgets(
    'a failed initial load shows the error message and a retry button',
    (tester) async {
      when(getBrandKitUseCase.call).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection. Check your network and try again.',
          ),
        ),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('brand_kit_retry_button')), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Save shows a loading state on the button, then a success '
    'snack bar once the save completes',
    (tester) async {
      when(
        getBrandKitUseCase.call,
      ).thenAnswer((_) async => Result.ok(brandKit));
      when(() => updateBrandKitUseCase(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Result.ok(brandKit);
      });

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('brand_kit_save_button')),
      );
      await tester.tap(find.byKey(const Key('brand_kit_save_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Brand kit saved.'), findsOneWidget);
    },
  );

  testWidgets('a failed save shows the plain-language error in a SnackBar', (
    tester,
  ) async {
    when(getBrandKitUseCase.call).thenAnswer((_) async => Result.ok(brandKit));
    when(() => updateBrandKitUseCase(any())).thenAnswer(
      (_) async => const Result.err(
        ApiFailure(
          type: ApiErrorType.validationError,
          message: 'Please check your input and try again.',
        ),
      ),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('brand_kit_save_button')));
    await tester.tap(find.byKey(const Key('brand_kit_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Please check your input and try again.'), findsOneWidget);
  });

  testWidgets(
    'an invalid hex color blocks the save locally without calling the use '
    'case',
    (tester) async {
      when(
        getBrandKitUseCase.call,
      ).thenAnswer((_) async => Result.ok(brandKit));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '#855312'),
        'not-a-color',
      );
      await tester.ensureVisible(
        find.byKey(const Key('brand_kit_save_button')),
      );
      await tester.tap(find.byKey(const Key('brand_kit_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid hex color, e.g. #855312.'), findsWidgets);
      verifyNever(() => updateBrandKitUseCase(any()));
    },
  );
}
