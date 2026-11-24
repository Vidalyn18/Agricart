import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';

const double kLowStockThreshold = 10;

class SellerService {
  SellerService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<MarketplaceOrder>> fetchSellerOrders({
    OrderStatus? status,
  }) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw const AuthException('Sign in as a Seller.');
    var request = _client
        .from('orders')
        .select('*, order_items(*)')
        .eq('seller_id', sellerId);
    if (status != null) {
      request = request.eq('status', status.value);
    }
    final rows = await request.order('created_at', ascending: false);
    return rows.map((row) {
      final orderRow = Map<String, dynamic>.from(row);
      final itemRows = (orderRow['order_items'] as List? ?? const [])
          .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      return MarketplaceOrder.fromMap(
        orderRow,
      ).copyWith(items: itemRows, itemCount: itemRows.length);
    }).toList();
  }

  static Future<int> fetchPendingOrderCount() async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) return 0;
    final rows = await _client
        .from('orders')
        .select('id')
        .eq('seller_id', sellerId)
        .eq('status', 'pending');
    return rows.length;
  }

  static Future<MarketplaceOrder> fetchSellerOrder(String orderId) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw const AuthException('Sign in as a Seller.');
    final row = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .eq('seller_id', sellerId)
        .maybeSingle();
    if (row == null) throw StateError('Order not found.');
    final items = await _client
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    final history = await _client
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
    return MarketplaceOrder.fromMap(Map<String, dynamic>.from(row)).copyWith(
      items: items
          .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      statusHistory: history
          .map(
            (entry) =>
                OrderStatusHistory.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(),
    );
  }

  static Future<MarketplaceOrder> updateStatus({
    required String orderId,
    required OrderStatus status,
    DateTime? eta,
    String? riderName,
    String? riderPhone,
  }) async {
    final response = await _client.rpc(
      'update_order_status',
      params: {
        'p_order_id': orderId,
        'p_status': status.value,
        'p_eta': eta?.toUtc().toIso8601String(),
        'p_rider_name': riderName,
        'p_rider_phone': riderPhone,
      },
    );
    final row = switch (response) {
      Map value => Map<String, dynamic>.from(value),
      List values when values.length == 1 => Map<String, dynamic>.from(
        values.single as Map,
      ),
      _ => throw StateError(
        'Supabase returned an invalid update_order_status response.',
      ),
    };
    return MarketplaceOrder.fromMap(row);
  }

  static Future<Map<String, dynamic>> fetchSales(int periodDays) async {
    if (![7, 30, 90].contains(periodDays)) {
      throw ArgumentError.value(
        periodDays,
        'periodDays',
        'Must be 7, 30, or 90.',
      );
    }
    final response = await _client.rpc(
      'get_seller_sales',
      params: {'p_days': periodDays},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw StateError('Supabase returned an invalid sales response.');
  }
}
