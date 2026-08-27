import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_bloc.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_delete_confirm_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_delete_consequence_page.dart';
import 'package:kelal_studio/features/settings/presentation/pages/account_page.dart';
import 'package:mocktail/mocktail.dart';

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

void main() {
  late MockDeleteAccountUseCase deleteAccountUseCase;

  setUp(() {
    deleteAccountUseCase = MockDeleteAccountUseCase();
    getIt.registerFactory<AccountBloc>(() => AccountBloc(deleteAccountUseCase));
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/settings/account',
      routes: [
        GoRoute(
          path: '/settings/account',
          builder: (context, state) => const AccountPage(),
        ),
        GoRoute(
          path: '/settings/account_delete_consequence',
          builder: (context, state) => const AccountDeleteConsequencePage(),
        ),
        GoRoute(
          path: '/settings/account_delete_confirm',
          builder: (context, state) => const AccountDeleteConfirmPage(),
        ),
        GoRoute(
          path: '/settings/account_deleted',
          builder: (context, state) =>
              const Scaffold(body: Text('Account Deleted Page')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('AccountPage renders UI correctly', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('you@business.com'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('Tapping delete navigates to consequence page', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This permanently deletes your account and everything tied to it:',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Confirming deletion shows loading indicator and navigates', (
    tester,
  ) async {
    when(() => deleteAccountUseCase()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const Result.ok(null);
    });

    await tester.pumpWidget(wrap());

    // Navigate to consequence
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    // Navigate to confirm
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify confirm page UI
    expect(find.text('Why are you leaving? (optional)'), findsOneWidget);

    // Type DELETE
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();

    // Tap permanently delete
    await tester.tap(find.text('Permanently Delete Account'));
    await tester.pump();

    // Loading indicator appears
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // The router should have navigated to the account deleted page
    expect(find.text('Account Deleted Page'), findsOneWidget);
  });
}
