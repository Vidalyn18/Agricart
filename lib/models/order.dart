enum FulfillmentType {
  delivery('delivery', 'Delivery'),
  pickup('pickup', 'Pickup');

  const FulfillmentType(this.value, this.label);

  final String value;
  final String label;

  static FulfillmentType fromValue(Object? value) {
    return switch (value) {
      'delivery' => FulfillmentType.delivery,
      'pickup' => FulfillmentType.pickup,
      _ => throw FormatException('Unknown fulfillment type: $value'),
    };
  }
}

enum PaymentMethod {
  cod('cod'),
  gcash('gcash'),
  card('card');

  const PaymentMethod(this.value);

  final String value;

  String labelFor(FulfillmentType fulfillmentType) {
    return switch (this) {
      PaymentMethod.cod =>
        fulfillmentType == FulfillmentType.pickup
            ? 'Cash on Pickup'
            : 'Cash on Delivery',
      PaymentMethod.gcash => 'GCash (Demo)',
      PaymentMethod.card => 'Card (Demo)',
    };
  }

  static PaymentMethod fromValue(Object? value) {
    return switch (value) {
      'cod' => PaymentMethod.cod,
      'gcash' => PaymentMethod.gcash,
      'card' => PaymentMethod.card,
      _ => throw FormatException('Unknown payment method: $value'),
    };
  }
}

enum OrderStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  preparing('preparing', 'Preparing'),
  outForDelivery('out_for_delivery', 'Out for Delivery'),
  readyForPickup('ready_for_pickup', 'Ready for Pickup'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus fromValue(Object? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    throw FormatException('Unknown order status: $value');
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.imagePath,
    required this.pricePerKg,
    required this.quantityKg,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> row) {
    return OrderItem(
      id: row['id'].toString(),
      orderId: row['order_id'].toString(),
      productId: row['product_id'].toString(),
      productName: row['product_name'] as String,
      imagePath: row['image_path'] as String?,
      pricePerKg: _asDouble(row['price_per_kg']),
      quantityKg: _asDouble(row['quantity_kg']),
      lineTotal: _asDouble(row['line_total']),
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> row) =>
      OrderItem.fromJson(row);

  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final String? imagePath;
  final double pricePerKg;
  final double quantityKg;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_id': orderId,
    'product_id': productId,
    'product_name': productName,
    'image_path': imagePath,
    'price_per_kg': pricePerKg,
    'quantity_kg': quantityKg,
    'line_total': lineTotal,
  };
}

class OrderStatusHistory {
  const OrderStatusHistory({
    required this.id,
    required this.orderId,
    required this.status,
    required this.createdAt,
  });

  factory OrderStatusHistory.fromMap(Map<String, dynamic> row) {
    return OrderStatusHistory(
      id: row['id'].toString(),
      orderId: row['order_id'].toString(),
      status: OrderStatus.fromValue(row['status']),
      createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
    );
  }

  final String id;
  final String orderId;
  final OrderStatus status;
  final DateTime createdAt;
}

class MarketplaceOrder {
  const MarketplaceOrder({
    required this.id,
    required this.orderNumber,
    required this.checkoutId,
    required this.buyerId,
    this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.fulfillmentType,
    required this.deliveryAddress,
    required this.contactName,
    required this.contactPhone,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.status,
    required this.eta,
    required this.riderName,
    required this.riderPhone,
    required this.createdAt,
    this.items = const [],
    this.statusHistory = const [],
    this.itemCount = 0,
  });

  factory MarketplaceOrder.fromJson(Map<String, dynamic> row) {
    return MarketplaceOrder(
      id: row['id'].toString(),
      orderNumber: row['order_number'] as String,
      checkoutId: row['checkout_id'].toString(),
      buyerId: row['buyer_id'].toString(),
      buyerName: row['buyer_name'] as String?,
      sellerId: row['seller_id'].toString(),
      sellerName: row['seller_name'] as String,
      fulfillmentType: FulfillmentType.fromValue(row['fulfillment_type']),
      deliveryAddress: row['delivery_address'] as String?,
      contactName: row['contact_name'] as String?,
      contactPhone: row['contact_phone'] as String?,
      paymentMethod: PaymentMethod.fromValue(row['payment_method']),
      subtotal: _asDouble(row['subtotal']),
      deliveryFee: _asDouble(row['delivery_fee']),
      total: _asDouble(row['total']),
      status: OrderStatus.fromValue(row['status']),
      eta: row['eta'] == null
          ? null
          : DateTime.parse(row['eta'].toString()).toLocal(),
      riderName: row['rider_name'] as String?,
      riderPhone: row['rider_phone'] as String?,
      createdAt: DateTime.parse(row['created_at'].toString()).toLocal(),
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory MarketplaceOrder.fromMap(Map<String, dynamic> row) =>
      MarketplaceOrder.fromJson(row);

  final String id;
  final String orderNumber;
  final String checkoutId;
  final String buyerId;
  final String? buyerName;
  final String sellerId;
  final String sellerName;
  final FulfillmentType fulfillmentType;
  final String? deliveryAddress;
  final String? contactName;
  final String? contactPhone;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final DateTime? eta;
  final String? riderName;
  final String? riderPhone;
  final DateTime createdAt;
  final List<OrderItem> items;
  final List<OrderStatusHistory> statusHistory;
  final int itemCount;

  MarketplaceOrder copyWith({
    int? itemCount,
    List<OrderItem>? items,
    List<OrderStatusHistory>? statusHistory,
  }) {
    return MarketplaceOrder(
      id: id,
      orderNumber: orderNumber,
      checkoutId: checkoutId,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      sellerName: sellerName,
      fulfillmentType: fulfillmentType,
      deliveryAddress: deliveryAddress,
      contactName: contactName,
      contactPhone: contactPhone,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      status: status,
      eta: eta,
      riderName: riderName,
      riderPhone: riderPhone,
      createdAt: createdAt,
      items: items ?? this.items,
      statusHistory: statusHistory ?? this.statusHistory,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_number': orderNumber,
    'checkout_id': checkoutId,
    'buyer_id': buyerId,
    'buyer_name': buyerName,
    'seller_id': sellerId,
    'seller_name': sellerName,
    'fulfillment_type': fulfillmentType.value,
    'delivery_address': deliveryAddress,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'payment_method': paymentMethod.value,
    'subtotal': subtotal,
    'delivery_fee': deliveryFee,
    'total': total,
    'status': status.value,
    'eta': eta?.toUtc().toIso8601String(),
    'rider_name': riderName,
    'rider_phone': riderPhone,
    'created_at': createdAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'item_count': itemCount,
  };
}

class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.sellerName,
    required this.total,
  });

  factory PlacedOrder.fromMap(Map<String, dynamic> row) => PlacedOrder(
    id: row['id'].toString(),
    orderNumber: row['order_number'] as String,
    sellerName: row['seller_name'] as String,
    total: _asDouble(row['total']),
  );

  final String id;
  final String orderNumber;
  final String sellerName;
  final double total;
}

typedef Order = MarketplaceOrder;

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('Expected a numeric order value, got $value.');
}
