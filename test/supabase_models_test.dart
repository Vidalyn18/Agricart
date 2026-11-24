import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/order.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/models/profile.dart';

void main() {
  test('profile, product, order, and order item map JSON field names', () {
    final profile = Profile.fromJson({
      'id': 'user-id',
      'role': 'seller',
      'full_name': 'Mila Santos',
      'email': 'mila@example.test',
      'farm_name': 'Mila Farm',
    });
    expect(profile.toJson()['farm_name'], 'Mila Farm');

    final product = Product.fromJson({
      'id': 'product-id',
      'seller_id': profile.id,
      'seller_name': profile.farmName,
      'name': 'Tomato',
      'category': 'vegetables',
      'subcategory': 'Fruiting vegetables',
      'price_per_kg': 88,
      'rating': 4.8,
      'stock_kg': 12,
      'harvest_date': '2026-11-23',
      'is_discounted': false,
    });
    expect(product.toJson()['price_per_kg'], 88);
    expect(product.toJson()['category'], 'vegetables');

    final order = Order.fromJson({
      'id': 'order-id',
      'order_number': 'AGC123456',
      'checkout_id': 'checkout-id',
      'buyer_id': 'buyer-id',
      'seller_id': profile.id,
      'seller_name': 'Mila Farm',
      'buyer_name': 'Buyer Name',
      'fulfillment_type': 'pickup',
      'payment_method': 'cod',
      'subtotal': 88,
      'delivery_fee': 0,
      'total': 88,
      'status': 'pending',
      'created_at': '2026-11-24T00:00:00Z',
    });
    expect(order.toJson()['buyer_name'], 'Buyer Name');

    final item = OrderItem.fromJson({
      'id': 'item-id',
      'order_id': order.id,
      'product_id': product.id,
      'product_name': product.name,
      'price_per_kg': 88,
      'quantity_kg': 1,
      'line_total': 88,
    });
    expect(item.toJson()['quantity_kg'], 1);
  });
}
