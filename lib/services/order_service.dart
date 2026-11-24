import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import 'cart_service.dart';

class OrderService {
  OrderService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String get _buyerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to view your orders.');
    return id;
  }

  static Future<List<MarketplaceOrder>> fetchBuyerOrders() async {
    final orderRows = await _client
        .from('orders')
        .select('*, order_items(*), order_status_history(*)')
        .eq('buyer_id', _buyerId)
        .order('created_at', ascending: false);
    return orderRows
        .map((row) => _orderWithRelations(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<MarketplaceOrder> fetchOrderDetails(String orderId) async {
    final row = await _client
        .from('orders')
        .select('*, order_items(*), order_status_history(*)')
        .eq('id', orderId)
        .eq('buyer_id', _buyerId)
        .maybeSingle();
    if (row == null) throw StateError('Order not found.');
    return _orderWithRelations(Map<String, dynamic>.from(row));
  }

  static Future<List<PlacedOrder>> placeOrder({
    required List<CartItem> items,
    required FulfillmentType fulfillmentType,
    required String deliveryAddress,
    required String contactName,
    required String contactPhone,
    required PaymentMethod paymentMethod,
    required double deliveryFeePerSeller,
  }) async {
    final response = await _client.rpc(
      'place_order',
      params: {
        'p_items': items
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity_kg': item.quantityKg,
              },
            )
            .toList(),
        'p_fulfillment': fulfillmentType.value,
        'p_payment': paymentMethod.value,
        'p_delivery_address': fulfillmentType == FulfillmentType.delivery
            ? deliveryAddress
            : null,
        'p_contact_name': fulfillmentType == FulfillmentType.delivery
            ? contactName
            : null,
        'p_contact_phone': fulfillmentType == FulfillmentType.delivery
            ? contactPhone
            : null,
        'p_delivery_fee': deliveryFeePerSeller,
      },
    );
    if (response is! List) {
      throw StateError('Supabase returned an invalid place_order response.');
    }
    return response
        .map(
          (row) => PlacedOrder.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  static Future<void> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    await _client.rpc(
      'cancel_order',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
  }

  static String errorMessage(Object error) {
    if (error is StateError) {
      final message = error.message.trim();
      return message.startsWith('{')
          ? 'The order could not be completed. Please try again.'
          : message;
    }
    if (error is AuthException) {
      return 'Your session may have expired. Please sign in again.';
    }
    if (error is PostgrestException) {
      final details = error.message.trim();
      final lower = details.toLowerCase();
      if (lower.contains('network') ||
          lower.contains('socket') ||
          lower.contains('connection') ||
          lower.contains('timed out') ||
          lower.contains('failed to fetch')) {
        return 'No connection. Check your internet and try again.';
      }
      if (error.code == '42501') {
        return 'You do not have permission to change this order.';
      }
      if (details.startsWith('{')) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map<String, dynamic>) {
            final message = decoded['message']?.toString().trim();
            if (message != null &&
                message.isNotEmpty &&
                !message.startsWith('{')) {
              return _friendlyDatabaseMessage(message);
            }
          }
        } on FormatException {
          return 'The order could not be completed. Please try again.';
        }
        return 'The order could not be completed. Please try again.';
      }
      return _friendlyDatabaseMessage(details);
    }
    return 'Something went wrong. Please try again.';
  }

  static String _friendlyDatabaseMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not enough stock') ||
        lower.contains('insufficient stock') ||
        lower.contains('out of stock')) {
      final product = RegExp(
        r'(?:not enough stock for|insufficient stock for|out of stock for)\s+([^\.\n]+)',
        caseSensitive: false,
      ).firstMatch(message)?.group(1)?.trim();
      return product == null || product.isEmpty
          ? 'One or more products do not have enough stock. Update your cart and try again.'
          : 'Not enough stock for $product.';
    }
    if (lower.contains('order') && lower.contains('cancel')) {
      return 'This order can no longer be cancelled.';
    }
    if (lower.contains('permission denied') ||
        lower.contains('violates row-level security')) {
      return 'You do not have permission to change this order.';
    }
    return 'The order could not be completed. Please try again.';
  }

  static MarketplaceOrder _orderWithRelations(Map<String, dynamic> row) {
    final items = (row['order_items'] as List? ?? const [])
        .map(
          (item) => OrderItem.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final history =
        (row['order_status_history'] as List? ?? const [])
            .map(
              (entry) => OrderStatusHistory.fromMap(
                Map<String, dynamic>.from(entry as Map),
              ),
            )
            .toList()
          ..sort(
            (first, second) => first.createdAt.compareTo(second.createdAt),
          );
    return MarketplaceOrder.fromMap(
      row,
    ).copyWith(items: items, statusHistory: history, itemCount: items.length);
  }
}
