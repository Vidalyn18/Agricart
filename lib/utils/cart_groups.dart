import '../services/cart_service.dart';

Map<String, List<CartItem>> groupCartItems(List<CartItem> items) {
  final groups = <String, List<CartItem>>{};
  for (final item in items) {
    groups.putIfAbsent(item.sellerId, () => []).add(item);
  }
  return groups;
}
