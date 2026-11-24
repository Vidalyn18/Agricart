import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shared start flow reaches login and validates empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(supabaseConfigured: false));

    expect(find.text('Tap the logo to continue'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Tap the logo to continue'), findsOneWidget);

    await tester.tap(find.text('AgriCart'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh from local growers to your table'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh produce, every day'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to AgriCart!'), findsOneWidget);

    await tester.tap(find.text('Buyer'));
    final sellerContinue = find.text('Continue');
    await tester.ensureVisible(sellerContinue);
    await tester.pumpAndSettle();
    await tester.tap(sellerContinue);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byTooltip('Show password'), findsOneWidget);

    final loginContinue = find.text('Continue');
    await tester.ensureVisible(loginContinue);
    await tester.pumpAndSettle();
    await tester.tap(loginContinue);
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);

    var signUp = find.text('Sign Up');
    await tester.ensureVisible(signUp);
    await tester.pumpAndSettle();
    await tester.tap(signUp);
    await tester.pumpAndSettle();
    expect(find.text('Join AgriCart as a Buyer.'), findsOneWidget);
    expect(find.text('Farm or business name'), findsNothing);

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
    final seller = find.text('Seller');
    await tester.ensureVisible(seller);
    await tester.pumpAndSettle();
    await tester.tap(seller);
    final continueButton = find.text('Continue');
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    signUp = find.text('Sign Up');
    await tester.ensureVisible(signUp);
    await tester.pumpAndSettle();
    await tester.tap(signUp);
    await tester.pumpAndSettle();
    expect(find.text('Join AgriCart as a Seller.'), findsOneWidget);
    expect(find.text('Farm or business name'), findsOneWidget);
  });
}
