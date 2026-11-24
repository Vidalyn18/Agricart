import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'models/order.dart';
import 'services/order_service.dart';
import 'utils/format_currency.dart';
import 'widgets/app_button.dart';
import 'widgets/price_summary.dart';
import 'widgets/product_image.dart';
import 'widgets/status_chip.dart';

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orders});

  final List<PlacedOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: _OrderError(
            message: 'Order confirmation details could not be loaded.',
            onRetry: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => route.isFirst,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 38, 22, 30),
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 78,
              color: AgriCartColors.buttonGreen,
            ),
            const SizedBox(height: 17),
            Text(
              'Order placed!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order has been sent to the seller.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AgriCartColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 24),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AgriCartColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: AgriCartColors.darkGreen,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: const TextStyle(
                                color: AgriCartColors.darkGreen,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sold by ${order.sellerName}',
                              style: const TextStyle(
                                color: AgriCartColors.mutedText,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatPeso(order.total),
                              style: const TextStyle(
                                color: AgriCartColors.darkGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            AppButton(
              label: 'View My Orders',
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/orders',
                (route) => route.isFirst,
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Continue Shopping',
              outlined: true,
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => route.isFirst,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OrdersFilter { active, completedCancelled }

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<MarketplaceOrder>> _orders = _fetchOrders();
  _OrdersFilter _filter = _OrdersFilter.active;

  Future<List<MarketplaceOrder>> _fetchOrders() {
    if (!widget.supabaseConfigured) {
      return Future.error(StateError('Connect Supabase to view your orders.'));
    }
    return OrderService.fetchBuyerOrders();
  }

  Future<void> _refresh() async {
    final future = _fetchOrders();
    setState(() => _orders = future);
    await future;
  }

  List<MarketplaceOrder> _filtered(List<MarketplaceOrder> orders) {
    return switch (_filter) {
      _OrdersFilter.active =>
        orders
            .where(
              (order) =>
                  order.status != OrderStatus.completed &&
                  order.status != OrderStatus.cancelled,
            )
            .toList(),
      _OrdersFilter.completedCancelled =>
        orders
            .where(
              (order) =>
                  order.status == OrderStatus.completed ||
                  order.status == OrderStatus.cancelled,
            )
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const _OrdersHeader(title: 'My Orders'),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: Row(
              children: [
                for (final filter in _OrdersFilter.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _OrdersFilterButton(
                        label: switch (filter) {
                          _OrdersFilter.active => 'Active',
                          _OrdersFilter.completedCancelled =>
                            'Completed/Cancelled',
                        },
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MarketplaceOrder>>(
              future: _orders,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _OrderError(
                    message: OrderService.errorMessage(snapshot.error!),
                    onRetry: () => setState(() => _orders = _fetchOrders()),
                  );
                }
                if (!snapshot.hasData) return const _OrderLoading();
                final orders = _filtered(snapshot.data!);
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AgriCartColors.buttonGreen,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 80, 22, 28),
                      children: [_OrdersEmpty(filter: _filter)],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: AgriCartColors.buttonGreen,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 5, 18, 28),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 11),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderListCard(
                        order: order,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/order-details',
                          arguments: order.id,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersFilterButton extends StatelessWidget {
  const _OrdersFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: selected ? Colors.white : AgriCartColors.darkGreen,
        backgroundColor: selected ? AgriCartColors.buttonGreen : Colors.white,
        side: BorderSide(
          color: selected
              ? AgriCartColors.buttonGreen
              : AgriCartColors.cardBorder,
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({required this.order, required this.onTap});

  final MarketplaceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AgriCartColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      style: const TextStyle(
                        color: AgriCartColors.darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Sold by ${order.sellerName}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · ${_formatDate(order.createdAt)}',
                style: const TextStyle(
                  color: AgriCartColors.mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text('Order total', style: TextStyle(fontSize: 13)),
                  ),
                  Text(
                    formatPeso(order.total),
                    style: const TextStyle(
                      color: AgriCartColors.darkGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.supabaseConfigured,
  });

  final String orderId;
  final bool supabaseConfigured;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Future<MarketplaceOrder> _order = _fetchOrder();
  bool _isCancelling = false;

  Future<MarketplaceOrder> _fetchOrder() {
    if (!widget.supabaseConfigured) {
      return Future.error(
        StateError('Connect Supabase to view order details.'),
      );
    }
    return OrderService.fetchOrderDetails(widget.orderId);
  }

  Future<void> _cancelOrder() async {
    final reason = await _askCancelReason(context);
    if (reason == null || !mounted) return;
    setState(() {
      _isCancelling = true;
    });
    try {
      await OrderService.cancelOrder(orderId: widget.orderId, reason: reason);
      if (mounted) {
        setState(() => _order = _fetchOrder());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order cancelled.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(OrderService.errorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _OrdersHeader(title: 'Order Details'),
            Expanded(
              child: FutureBuilder<MarketplaceOrder>(
                future: _order,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _OrderError(
                      message: OrderService.errorMessage(snapshot.error!),
                      onRetry: () => setState(() => _order = _fetchOrder()),
                    );
                  }
                  if (!snapshot.hasData) return const _OrderLoading();
                  final order = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNumber,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(order.createdAt),
                        style: const TextStyle(
                          color: AgriCartColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 13),
                      _OrderInfoCard(
                        title: 'Seller',
                        detail: order.sellerName,
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 10),
                      _OrderInfoCard(
                        title: order.fulfillmentType.label,
                        detail:
                            order.fulfillmentType == FulfillmentType.delivery
                            ? '${order.deliveryAddress ?? ''}\n${order.contactName ?? ''} · ${order.contactPhone ?? ''}'
                            : 'Seller will confirm pickup details',
                        icon: order.fulfillmentType == FulfillmentType.delivery
                            ? Icons.local_shipping_outlined
                            : Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 10),
                      _OrderInfoCard(
                        title: 'Payment method',
                        detail: order.paymentMethod.labelFor(
                          order.fulfillmentType,
                        ),
                        icon: Icons.payments_outlined,
                      ),
                      const SizedBox(height: 17),
                      Text(
                        'Items',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final item in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OrderItemTile(item: item),
                        ),
                      const SizedBox(height: 8),
                      PriceSummary(
                        subtotal: order.subtotal,
                        deliveryFee: order.deliveryFee,
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Track Order',
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/order-tracking',
                          arguments: order.id,
                        ),
                      ),
                      if (_canCancel(order.status)) ...[
                        const SizedBox(height: 9),
                        AppButton(
                          label: _isCancelling ? 'Cancelling…' : 'Cancel Order',
                          outlined: true,
                          isLoading: _isCancelling,
                          onPressed: _isCancelling ? null : _cancelOrder,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              child: AspectRatio(
                aspectRatio: 1,
                child: ProductImage(imagePath: item.imagePath),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatKg(item.quantityKg)} kg · ${formatPeso(item.pricePerKg)} / kg',
                  style: const TextStyle(
                    color: AgriCartColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(item.lineTotal),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.supabaseConfigured,
  });

  final String orderId;
  final bool supabaseConfigured;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  MarketplaceOrder? _order;
  Object? _error;
  bool _isLoading = true;
  bool _isCancelling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(silent: true),
    );
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!widget.supabaseConfigured) {
      setState(() {
        _error = StateError('Connect Supabase to track your order.');
        _isLoading = false;
      });
      return;
    }
    if (!silent && _order == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final order = await OrderService.fetchOrderDetails(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder() async {
    final order = _order;
    if (order == null || !_canCancel(order.status)) return;
    final reason = await _askCancelReason(context);
    if (reason == null || !mounted) return;
    setState(() => _isCancelling = true);
    try {
      await OrderService.cancelOrder(orderId: order.id, reason: reason);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order cancelled.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(OrderService.errorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _OrdersHeader(title: 'Order Tracking'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AgriCartColors.buttonGreen,
                child: _isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 130),
                            child: _OrderLoading(),
                          ),
                        ],
                      )
                    : order == null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 90, 24, 28),
                        children: [
                          _OrderError(
                            message: OrderService.errorMessage(
                              _error ?? StateError('Order not found.'),
                            ),
                            onRetry: _refresh,
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.orderNumber,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              StatusChip(status: order.status),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Sold by ${order.sellerName}',
                            style: const TextStyle(
                              color: AgriCartColors.mutedText,
                              fontSize: 13,
                            ),
                          ),
                          if (order.eta != null) ...[
                            const SizedBox(height: 15),
                            _OrderInfoCard(
                              title: 'Estimated arrival',
                              detail: _formatDateTime(order.eta!),
                              icon: Icons.schedule_outlined,
                            ),
                          ],
                          if ((order.riderName?.isNotEmpty ?? false) ||
                              (order.riderPhone?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 10),
                            _OrderInfoCard(
                              title: 'Rider',
                              detail: [
                                if (order.riderName?.isNotEmpty == true)
                                  order.riderName!,
                                if (order.riderPhone?.isNotEmpty == true)
                                  order.riderPhone!,
                              ].join('\n'),
                              icon: Icons.delivery_dining_outlined,
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'Order progress',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _OrderTimeline(order: order),
                          const SizedBox(height: 16),
                          _OrderInfoCard(
                            title: order.fulfillmentType.label,
                            detail:
                                order.fulfillmentType ==
                                    FulfillmentType.delivery
                                ? '${order.deliveryAddress ?? ''}\n${order.contactName ?? ''} · ${order.contactPhone ?? ''}'
                                : (order.deliveryAddress?.isNotEmpty == true
                                      ? order.deliveryAddress!
                                      : 'Pickup details will be sent after confirmation'),
                            icon:
                                order.fulfillmentType ==
                                    FulfillmentType.delivery
                                ? Icons.local_shipping_outlined
                                : Icons.storefront_outlined,
                          ),
                          const SizedBox(height: 10),
                          _OrderInfoCard(
                            title: 'Payment method',
                            detail: order.paymentMethod.labelFor(
                              order.fulfillmentType,
                            ),
                            icon: Icons.payments_outlined,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Items',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          for (final item in order.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _OrderItemTile(item: item),
                            ),
                          const SizedBox(height: 8),
                          PriceSummary(
                            subtotal: order.subtotal,
                            deliveryFee: order.deliveryFee,
                          ),
                          const SizedBox(height: 14),
                          if (order.fulfillmentType ==
                                  FulfillmentType.delivery &&
                              order.riderPhone != null &&
                              order.riderPhone!.isNotEmpty)
                            AppButton(
                              label: 'Call Rider',
                              icon: const Icon(Icons.call_outlined, size: 18),
                              onPressed: () => _callRider(context, order),
                            ),
                          if (_canCancel(order.status)) ...[
                            const SizedBox(height: 9),
                            AppButton(
                              label: _isCancelling
                                  ? 'Cancelling…'
                                  : 'Cancel Order',
                              outlined: true,
                              isLoading: _isCancelling,
                              onPressed: _isCancelling ? null : _cancelOrder,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callRider(BuildContext context, MarketplaceOrder order) async {
    final phone = order.riderPhone;
    if (phone == null || phone.isEmpty) return;
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }
}

bool _canCancel(OrderStatus status) =>
    status == OrderStatus.pending || status == OrderStatus.confirmed;

Future<String?> _askCancelReason(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _CancelOrderReasonDialog(),
  );
}

class _CancelOrderReasonDialog extends StatefulWidget {
  const _CancelOrderReasonDialog();

  @override
  State<_CancelOrderReasonDialog> createState() =>
      _CancelOrderReasonDialogState();
}

class _CancelOrderReasonDialogState extends State<_CancelOrderReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this order?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please tell us why you are cancelling.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter a reason to continue.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Order'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _reasonController.text.trim());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9A3832),
            minimumSize: const Size(44, 44),
          ),
          child: const Text('Cancel Order'),
        ),
      ],
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.order});

  final MarketplaceOrder order;

  @override
  Widget build(BuildContext context) {
    final isDelivery = order.fulfillmentType == FulfillmentType.delivery;
    final recordedStatuses = order.statusHistory
        .map((entry) => entry.status)
        .toSet();
    final steps = order.status == OrderStatus.cancelled
        ? <(OrderStatus, String)>[
            (OrderStatus.pending, 'Order Placed'),
            if (recordedStatuses.contains(OrderStatus.confirmed))
              (OrderStatus.confirmed, 'Confirmed'),
            (OrderStatus.cancelled, 'Cancelled'),
          ]
        : <(OrderStatus, String)>[
            (OrderStatus.pending, 'Order Placed'),
            (OrderStatus.confirmed, 'Confirmed'),
            (OrderStatus.preparing, 'Preparing'),
            if (isDelivery)
              (OrderStatus.outForDelivery, 'Out for Delivery')
            else
              (OrderStatus.readyForPickup, 'Ready for Pickup'),
            (OrderStatus.completed, isDelivery ? 'Delivered' : 'Completed'),
          ];
    final currentIndex = steps.indexWhere((step) => step.$1 == order.status);
    final activeIndex = currentIndex < 0 ? 0 : currentIndex;
    final historyByStatus = <OrderStatus, DateTime>{};
    for (final history in order.statusHistory) {
      historyByStatus[history.status] = history.createdAt;
    }
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            status: steps[index].$1,
            label: steps[index].$2,
            time: historyByStatus[steps[index].$1],
            completed: index <= activeIndex,
            current: index == activeIndex,
            showConnector: index < steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.label,
    required this.time,
    required this.completed,
    required this.current,
    required this.showConnector,
  });

  final OrderStatus status;
  final String label;
  final DateTime? time;
  final bool completed;
  final bool current;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? AgriCartColors.buttonGreen
        : const Color(0xFFD8E1D9);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: current ? AgriCartColors.buttonGreen : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: completed && !current
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                if (showConnector)
                  Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: completed
                          ? AgriCartColors.darkGreen
                          : AgriCartColors.mutedText,
                      fontSize: 14,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(time!),
                      style: const TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AgriCartColors.darkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AgriCartColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _OrderLoading extends StatelessWidget {
  const _OrderLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AgriCartColors.buttonGreen),
    );
  }
}

class _OrderError extends StatelessWidget {
  const _OrderError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 45),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(110, 44)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.filter});

  final _OrdersFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      _OrdersFilter.active => 'You have no active orders.',
      _OrdersFilter.completedCancelled =>
        'No completed or cancelled orders yet.',
    };
    return Column(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 52,
          color: AgriCartColors.buttonGreen,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(local)} · $hour:$minute $meridiem';
}
