import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/order.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/services/cart_service.dart';
import 'package:flutter_application_1/services/checkout_state.dart';

void main() {
  final cart = CartService.instance;
  final checkout = CheckoutState.instance;

  setUp(() {
    cart.clear();
    checkout.clearAfterOrder();
  });

  tearDown(() {
    cart.clear();
    checkout.clearAfterOrder();
  });

  test('delivery fee is per unique seller and pickup is free', () {
    cart
      ..addProduct(_product('tomato', 'seller-one', 20))
      ..addProduct(_product('pechay', 'seller-one', 30))
      ..addProduct(_product('mango', 'seller-two', 40));

    checkout.setFulfillmentType(FulfillmentType.delivery);
    expect(checkout.sellerCount, 2);
    expect(checkout.subtotal, 90);
    expect(checkout.deliveryFeePerSeller, 50);
    expect(checkout.deliveryFee, 100);
    expect(checkout.total, 190);

    cart.removeProduct('mango');
    expect(checkout.sellerCount, 1);
    expect(checkout.subtotal, 50);
    expect(checkout.deliveryFeePerSeller, 50);
    expect(checkout.deliveryFee, 50);
    expect(checkout.total, 100);

    checkout.setFulfillmentType(FulfillmentType.pickup);
    expect(checkout.deliveryFeePerSeller, 0);
    expect(checkout.deliveryFee, 0);
    expect(checkout.total, 50);
  });
}

Product _product(String id, String sellerId, double price) {
  return Product(
    id: id,
    name: id,
    category: ProductCategory.vegetables,
    subcategory: 'Fresh produce',
    pricePerKg: price,
    rating: 4.5,
    stockKg: 5,
    sellerId: sellerId,
    sellerName: sellerId,
    imageUrl: null,
    description: '',
    harvestDate: DateTime(2026, 11, 24),
    isDiscounted: false,
    discountPrice: null,
  );
}
