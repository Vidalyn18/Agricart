import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/services/cart_service.dart';

void main() {
  final cart = CartService.instance;

  setUp(cart.clear);
  tearDown(cart.clear);

  test('merges repeated products and caps total quantity at stock', () {
    final product = _product(id: 'tomato', stockKg: 1.5);

    expect(cart.addProduct(product), CartAddResult.added);
    expect(cart.addProduct(product), CartAddResult.stockLimit);
    expect(cart.itemCount, 1);
    expect(cart.quantityForProduct(product.id), 1.5);
  });

  test('does not add products below the half kilogram minimum', () {
    final product = _product(id: 'pechay', stockKg: 0.25);

    expect(cart.addProduct(product), CartAddResult.minimumQuantity);
    expect(cart.items, isEmpty);
  });

  test('supports half-kilogram quantities and discounted cart prices', () {
    final product = _product(
      id: 'mango',
      stockKg: 2,
      pricePerKg: 100,
      isDiscounted: true,
      discountPrice: 75,
    );

    expect(cart.addProduct(product, quantityKg: 0.5), CartAddResult.added);
    final item = cart.items.single;
    expect(item.productId, 'mango');
    expect(item.name, 'mango');
    expect(item.sellerId, 'seller');
    expect(item.sellerName, 'Local Seller');
    expect(item.pricePerKg, 75);
    expect(item.quantityKg, 0.5);
  });

  test(
    'quantity changes and stock refreshes never leave quantity over stock',
    () {
      final product = _product(id: 'tomato', stockKg: 4);
      cart.addProduct(product);

      cart.setQuantity(product.id, 9);
      expect(cart.quantityForProduct(product.id), 4);

      final updatedProduct = _product(id: 'tomato', stockKg: 2);
      expect(cart.updateProduct(updatedProduct), isTrue);
      expect(cart.quantityForProduct(product.id), 2);
    },
  );

  test('subtotal rounds each product line to match stored order totals', () {
    final first = _product(id: 'a', stockKg: 2, pricePerKg: 0.01);
    final second = _product(id: 'b', stockKg: 2, pricePerKg: 0.01);
    cart
      ..addProduct(first)
      ..addProduct(second)
      ..setQuantity(first.id, 1.5)
      ..setQuantity(second.id, 1.5);

    expect(cart.subtotal, 0.04);
  });
}

Product _product({
  required String id,
  required double stockKg,
  double pricePerKg = 50,
  bool isDiscounted = false,
  double? discountPrice,
}) {
  return Product(
    id: id,
    name: id,
    category: ProductCategory.vegetables,
    subcategory: 'Leafy greens',
    pricePerKg: pricePerKg,
    rating: 4.5,
    stockKg: stockKg,
    sellerId: 'seller',
    sellerName: 'Local Seller',
    imageUrl: null,
    description: 'Fresh local produce.',
    harvestDate: DateTime(2026, 11, 22),
    isDiscounted: isDiscounted,
    discountPrice: discountPrice,
  );
}
