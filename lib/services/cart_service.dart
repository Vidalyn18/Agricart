import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../utils/format_currency.dart';

enum CartAddResult { added, stockLimit, outOfStock, minimumQuantity }

class CartItem {
  const CartItem({required this.product, required this.quantityKg});

  final Product product;
  final double quantityKg;

  String get productId => product.id;
  String get name => product.name;
  String? get imagePath => product.imageUrl;
  String get sellerId => product.sellerId;
  String get sellerName => product.sellerName;
  double get pricePerKg => product.currentPrice;
}

class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  double get totalKg =>
      _items.fold(0, (total, item) => total + item.quantityKg);
  double get subtotal => _items.fold(
    0,
    (total, item) =>
        total + roundCurrency(item.product.currentPrice * item.quantityKg),
  );

  double quantityForProduct(String productId) {
    for (final item in _items) {
      if (item.product.id == productId) return item.quantityKg;
    }
    return 0;
  }

  CartAddResult addProduct(Product product, {double quantityKg = 1}) {
    if (product.stockKg <= 0) {
      return CartAddResult.outOfStock;
    }
    if (product.stockKg < 0.5 || quantityKg < 0.5) {
      return CartAddResult.minimumQuantity;
    }

    final index = _items.indexWhere((item) => item.product.id == product.id);
    final existingQuantity = index == -1 ? 0 : _items[index].quantityKg;
    final nextQuantity = (existingQuantity + quantityKg)
        .clamp(0, product.stockKg)
        .toDouble();
    if (nextQuantity <= existingQuantity) return CartAddResult.stockLimit;

    final item = CartItem(product: product, quantityKg: nextQuantity);
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    notifyListeners();
    return nextQuantity < existingQuantity + quantityKg
        ? CartAddResult.stockLimit
        : CartAddResult.added;
  }

  bool setQuantity(String productId, double quantityKg) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return false;
    final item = _items[index];
    if (item.product.stockKg < 0.5) {
      _items.removeAt(index);
      notifyListeners();
      return true;
    }
    final quantity = quantityKg.clamp(0.5, item.product.stockKg).toDouble();
    if (quantity == item.quantityKg) return false;
    _items[index] = CartItem(product: item.product, quantityKg: quantity);
    notifyListeners();
    return true;
  }

  bool updateProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index == -1) return false;
    final item = _items[index];
    if (product.stockKg < 0.5) {
      _items.removeAt(index);
      notifyListeners();
      return true;
    }
    final quantity = item.quantityKg > product.stockKg
        ? product.stockKg
        : item.quantityKg;
    _items[index] = CartItem(product: product, quantityKg: quantity);
    notifyListeners();
    return quantity < item.quantityKg;
  }

  void removeProduct(String productId) {
    final oldLength = _items.length;
    _items.removeWhere((item) => item.product.id == productId);
    if (_items.length != oldLength) notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
