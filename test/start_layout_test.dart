import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/login_screens.dart';

void main() {
  const viewports = [
    Size(360, 640),
    Size(768, 1024),
    Size(800, 600),
    Size(1440, 900),
  ];

  for (final viewport in viewports) {
    testWidgets('onboarding is centered and scroll-safe at $viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: () {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);

      final artworkCard = find
          .ancestor(
            of: find.text('Farm-fresh goodness, all in one cart'),
            matching: find.byType(Container),
          )
          .first;
      final artworkRect = tester.getRect(artworkCard);
      final continueButton = find
          .descendant(
            of: find.byType(AppButton),
            matching: find.byType(SizedBox),
          )
          .first;
      final buttonRect = tester.getRect(continueButton);

      expect(artworkRect.width, closeTo(buttonRect.width, 0.5));
      expect(buttonRect.width, lessThanOrEqualTo(520));
      expect(artworkRect.center.dx, closeTo(viewport.width / 2, 1));

      final counterRect = tester.getRect(find.text('1 of 3'));
      final contentCenterY = (artworkRect.top + counterRect.bottom) / 2;
      final contentViewport = tester.getRect(
        find.byType(SingleChildScrollView),
      );
      expect(contentCenterY, closeTo(contentViewport.center.dy, 3));

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('role selection is centered and scroll-safe at $viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RoleSelectionScreen(onContinue: (_) {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to AgriCart!'), findsOneWidget);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);

      await tester.tap(find.text('Buyer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
