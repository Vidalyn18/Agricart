import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/product_image.dart';

void main() {
  testWidgets('empty product image paths show the leaf fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: ProductImage(imagePath: ''),
        ),
      ),
    );

    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });
}
