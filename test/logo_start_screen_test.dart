import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  for (final viewport in [const Size(360, 640), const Size(1440, 900)]) {
    testWidgets('logo lockup stays centered at $viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MyApp(supabaseConfigured: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tap the logo to continue'), findsNothing);
      expect(find.text('AgriCart'), findsOneWidget);

      final logo = find
          .ancestor(of: find.text('AgriCart'), matching: find.byType(Column))
          .last;
      final rect = tester.getRect(logo);
      expect(rect.center.dx, closeTo(viewport.width / 2, 1));
      expect(rect.center.dy, closeTo(viewport.height / 2, 1));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(viewport.height));
    });
  }
}
