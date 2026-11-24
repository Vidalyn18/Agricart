import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/password_field.dart';

void main() {
  testWidgets('password visibility toggles independently and keeps selection', (
    tester,
  ) async {
    final passwordController = TextEditingController(text: 'secret');
    final confirmController = TextEditingController(text: 'confirmation');
    passwordController.selection = const TextSelection.collapsed(offset: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PasswordField(controller: passwordController, label: 'Password'),
              PasswordField(
                controller: confirmController,
                label: 'Confirm password',
              ),
            ],
          ),
        ),
      ),
    );

    var fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.map((field) => field.obscureText), [true, true]);
    expect(find.bySemanticsLabel('Show password'), findsNWidgets(2));
    final showButtonFinder = find.ancestor(
      of: find.byTooltip('Show password').first,
      matching: find.byType(IconButton),
    );
    final showButton = tester.widget<IconButton>(showButtonFinder.first);
    expect((showButton.icon as Icon).icon, Icons.visibility_off_outlined);

    final showButtons = find.byTooltip('Show password');
    await tester.tap(showButtons.first);
    await tester.pumpAndSettle();

    fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.map((field) => field.obscureText), [false, true]);
    expect(passwordController.text, 'secret');
    expect(passwordController.selection.extentOffset, 2);
    final hideButtonFinder = find.ancestor(
      of: find.byTooltip('Hide password'),
      matching: find.byType(IconButton),
    );
    final hideButton = tester.widget<IconButton>(hideButtonFinder.first);
    expect((hideButton.icon as Icon).icon, Icons.visibility_outlined);
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);

    expect(hideButton.mouseCursor, SystemMouseCursors.click);
    expect(hideButton.constraints!.minWidth, greaterThanOrEqualTo(44));
    expect(hideButton.constraints!.minHeight, greaterThanOrEqualTo(44));

    await tester.pumpWidget(const SizedBox.shrink());
    passwordController.dispose();
    confirmController.dispose();
  });
}
