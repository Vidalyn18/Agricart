import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/models/order.dart';
import 'package:flutter_application_1/services/order_service.dart';

void main() {
  test('placed order parses the minimal place_order RPC response', () {
    final order = PlacedOrder.fromMap({
      'id': 'order-1',
      'order_number': 'AC-1001',
      'seller_name': 'Green Valley Farm',
      'total': 125.5,
    });

    expect(order.id, 'order-1');
    expect(order.orderNumber, 'AC-1001');
    expect(order.sellerName, 'Green Valley Farm');
    expect(order.total, 125.5);
  });

  test('order errors expose a readable stock message without raw JSON', () {
    expect(
      OrderService.errorMessage(
        PostgrestException(
          message: '{"code":"P0001","message":"Not enough stock for Tomato"}',
          code: 'P0001',
        ),
      ),
      'Not enough stock for Tomato.',
    );
  });
}
