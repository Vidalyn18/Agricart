import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shared start flow reaches login and validates empty fields', (
    tester,
  ) async {
    // Set a mobile-sized test screen.
    tester.view.physicalSize = const Size(402, 838);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(supabaseConfigured: false));
    await tester.pump();

    // Initial logo screen.
    expect(find.text('AgriCart'), findsOneWidget);

    // Open splash screen.
    await tester.tap(find.text('AgriCart'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh from local growers to your table'), findsOneWidget);

    // Open onboarding.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh produce, every day'), findsOneWidget);

    // Skip onboarding and open role selection.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to AgriCart!'), findsOneWidget);

    // Select Buyer and continue to login.
    await tester.tap(find.text('Buyer'));
    await tester.pumpAndSettle();

    final buyerContinue = find.text('Continue');
    await tester.ensureVisible(buyerContinue);
    await tester.pumpAndSettle();
    await tester.tap(buyerContinue);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byTooltip('Show password'), findsOneWidget);

    // Submit empty login fields and verify validation.
    final loginContinue = find.text('Continue');
    await tester.ensureVisible(loginContinue);
    await tester.pumpAndSettle();
    await tester.tap(loginContinue);
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);

    // Hide validation SnackBar before navigating.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    // Open Buyer registration.
    var signUp = find.text('Sign Up');
    await tester.ensureVisible(signUp);
    await tester.pumpAndSettle();
    await tester.tap(signUp);
    await tester.pumpAndSettle();

    expect(find.text('Join AgriCart as a Buyer.'), findsOneWidget);
    expect(find.text('Farm or business name'), findsNothing);

    // Return to login, then go back to role selection.
    final logIn = find.text('Log In');
    await tester.ensureVisible(logIn);
    await tester.pumpAndSettle();
    await tester.tap(logIn);
    await tester.pumpAndSettle();

    final back = find.byTooltip('Back');
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();

    // Select Seller and continue.
    final seller = find.text('Seller');
    await tester.ensureVisible(seller);
    await tester.pumpAndSettle();
    await tester.tap(seller);
    await tester.pumpAndSettle();

    final sellerContinue = find.text('Continue');
    await tester.ensureVisible(sellerContinue);
    await tester.pumpAndSettle();
    await tester.tap(sellerContinue);
    await tester.pumpAndSettle();

    // Open Seller registration.
    signUp = find.text('Sign Up');
    await tester.ensureVisible(signUp);
    await tester.pumpAndSettle();
    await tester.tap(signUp);
    await tester.pumpAndSettle();

    expect(find.text('Join AgriCart as a Seller.'), findsOneWidget);
    expect(find.text('Farm or business name'), findsOneWidget);
  });
}
