import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'services/buyer_account_service.dart';
import 'models/order.dart';
import 'services/cart_service.dart';
import 'services/checkout_state.dart';
import 'services/order_service.dart';
import 'services/product_service.dart';
import 'utils/cart_groups.dart';
import 'utils/format_currency.dart';
import 'widgets/app_button.dart';
import 'widgets/price_summary.dart';
import 'widgets/product_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isRevalidating = false;
  String? _stockNotice;
  String? _stockError;

  @override
  void initState() {
    super.initState();
    _revalidateStock();
  }

  Future<void> _revalidateStock() async {
    if (!widget.supabaseConfigured) {
      setState(() {
        _stockError = 'Connect Supabase to verify current stock.';
      });
      return;
    }
    setState(() {
      _isRevalidating = true;
      _stockError = null;
      _stockNotice = null;
    });
    var changed = false;
    try {
      final items = CartService.instance.items;
      for (final item in items) {
        try {
          final latest = await ProductService.fetchProduct(item.product.id);
          final stockReduced =
              latest.stockKg < item.quantityKg || latest.stockKg < 0.5;
          CartService.instance.updateProduct(latest);
          changed = changed || stockReduced;
        } on StateError catch (error) {
          if (error.message == 'This product is no longer available.') {
            CartService.instance.removeProduct(item.product.id);
            changed = true;
          } else {
            rethrow;
          }
        }
      }
      if (mounted && changed) {
        setState(() {
          _stockNotice =
              'Cart updated because one or more products have less stock now.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _stockError = OrderService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isRevalidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final items = CartService.instance.items;
        final groups = groupCartItems(items);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const _CheckoutHeader(title: 'My Cart'),
                const CheckoutStepIndicator(currentStep: 0),
                if (_stockNotice != null)
                  _MessageBanner(message: _stockNotice!, isError: false),
                if (_stockError != null)
                  _MessageBanner(
                    message: _stockError!,
                    isError: true,
                    actionLabel: 'Retry',
                    onAction: _revalidateStock,
                  ),
                Expanded(
                  child: items.isEmpty
                      ? _EmptyCart(
                          onStartShopping: () {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 190),
                          children: [
                            for (final group in groups.entries) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Sold by ${group.value.first.product.sellerName}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              for (final item in group.value)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: _CartItemTile(
                                    item: item,
                                    onQuantityChanged: (quantity) => CartService
                                        .instance
                                        .setQuantity(item.product.id, quantity),
                                    onRemove: () => CartService.instance
                                        .removeProduct(item.product.id),
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: AgriCartColors.cardBorder,
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PriceSummary(
                          subtotal: CartService.instance.subtotal,
                          showDeliveryFee: false,
                          showTotal: false,
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: 'Checkout',
                          onPressed: _isRevalidating
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  '/checkout-delivery',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final atStockLimit = item.quantityKg >= product.stockKg;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 76,
              child: AspectRatio(
                aspectRatio: 1,
                child: ProductImage(imagePath: product.imageUrl),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatPeso(product.currentPrice)} / kg',
                  style: const TextStyle(fontSize: 12),
                ),
                Row(
                  children: [
                    _KgStepper(
                      quantityKg: item.quantityKg,
                      stockKg: product.stockKg,
                      onChanged: onQuantityChanged,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove ${product.name}',
                      onPressed: onRemove,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFF9A3832),
                      ),
                    ),
                  ],
                ),
                if (atStockLimit)
                  const Text(
                    'Max stock reached',
                    style: TextStyle(
                      color: AgriCartColors.darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _KgStepper extends StatelessWidget {
  const _KgStepper({
    required this.quantityKg,
    required this.stockKg,
    required this.onChanged,
  });

  final double quantityKg;
  final double stockKg;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AgriCartColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: quantityKg > 0.5
                ? () => onChanged(quantityKg - 0.5)
                : null,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.remove, size: 17),
          ),
          Text(
            '${_formatKg(quantityKg)} kg',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: quantityKg < stockKg
                ? () => onChanged((quantityKg + 0.5).clamp(0.5, stockKg))
                : null,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add, size: 17),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onStartShopping});

  final VoidCallback onStartShopping;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 55,
              color: AgriCartColors.buttonGreen,
            ),
            const SizedBox(height: 12),
            Text(
              'Your cart is empty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Find something fresh from a local seller.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AgriCartColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 14),
            AppButton(label: 'Start Shopping', onPressed: onStartShopping),
          ],
        ),
      ),
    );
  }
}

class CheckoutDeliveryScreen extends StatefulWidget {
  const CheckoutDeliveryScreen({super.key});

  @override
  State<CheckoutDeliveryScreen> createState() => _CheckoutDeliveryScreenState();
}

class _CheckoutDeliveryScreenState extends State<CheckoutDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _streetController = TextEditingController(
    text: CheckoutState.instance.streetBarangay,
  );
  late final _cityController = TextEditingController(
    text: CheckoutState.instance.city,
  );
  late final _notesController = TextEditingController(
    text: CheckoutState.instance.deliveryNotes,
  );
  late final _nameController = TextEditingController(
    text: CheckoutState.instance.contactName,
  );
  late final _phoneController = TextEditingController(
    text: CheckoutState.instance.contactPhone,
  );
  List<SavedAddress> _savedAddresses = [];
  String? _selectedSavedAddressId;
  String? _savedAddressError;
  bool _isLoadingSavedAddresses = true;
  String _manualStreet = '';
  String _manualCity = '';
  String _manualName = '';
  String _manualPhone = '';
  Map<String, String> _pickupAddresses = {};
  bool _isLoadingPickupAddresses = false;
  String? _pickupAddressError;

  @override
  void initState() {
    super.initState();
    _loadCheckoutDetails();
  }

  Future<void> _loadCheckoutDetails() async {
    final checkout = CheckoutState.instance;
    await checkout.loadProfileDefaults();
    if (!mounted) return;
    _setControllerIfEmpty(_streetController, checkout.streetBarangay);
    _setControllerIfEmpty(_cityController, checkout.city);
    _setControllerIfEmpty(_notesController, checkout.deliveryNotes);
    _setControllerIfEmpty(_nameController, checkout.contactName);
    _setControllerIfEmpty(_phoneController, checkout.contactPhone);
    _rememberManualDetails();
    await _loadSavedAddresses(applyDefault: true);
  }

  Future<void> _loadSavedAddresses({bool applyDefault = false}) async {
    setState(() {
      _isLoadingSavedAddresses = true;
      _savedAddressError = null;
    });
    try {
      final addresses = await BuyerAccountService.fetchAddresses();
      if (!mounted) return;
      setState(() {
        _savedAddresses = addresses;
        _isLoadingSavedAddresses = false;
      });
      if (applyDefault) {
        final defaultAddress = addresses.where((item) => item.isDefault);
        if (defaultAddress.isNotEmpty) {
          _selectSavedAddress(defaultAddress.first.id);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _savedAddressError = BuyerAccountService.errorMessage(error);
          _isLoadingSavedAddresses = false;
        });
      }
    }
  }

  void _changeFulfillment(FulfillmentType value) {
    CheckoutState.instance.setFulfillmentType(value);
    if (value == FulfillmentType.pickup) _loadPickupAddresses();
  }

  Future<void> _loadPickupAddresses() async {
    final sellerIds = CartService.instance.items
        .map((item) => item.sellerId)
        .toSet()
        .toList();
    if (sellerIds.isEmpty ||
        sellerIds.every((sellerId) => _pickupAddresses.containsKey(sellerId))) {
      return;
    }
    setState(() {
      _isLoadingPickupAddresses = true;
      _pickupAddressError = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, pickup_address')
          .inFilter('id', sellerIds);
      if (!mounted) return;
      setState(() {
        _pickupAddresses = {
          for (final row in rows)
            row['id'].toString(): row['pickup_address']?.toString() ?? '',
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _pickupAddressError = OrderService.errorMessage(error));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pickup details are unavailable. Sellers will confirm pickup information.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPickupAddresses = false);
    }
  }

  void _rememberManualDetails() {
    _manualStreet = _streetController.text;
    _manualCity = _cityController.text;
    _manualName = _nameController.text;
    _manualPhone = _phoneController.text;
  }

  void _selectSavedAddress(String? id) {
    final checkout = CheckoutState.instance;
    if (id == null) {
      setState(() => _selectedSavedAddressId = null);
      _streetController.text = _manualStreet;
      _cityController.text = _manualCity;
      _nameController.text = _manualName;
      _phoneController.text = _manualPhone;
      checkout.setStreetBarangay(_manualStreet);
      checkout.setCity(_manualCity);
      checkout.setContactName(_manualName);
      checkout.setContactPhone(_manualPhone);
      return;
    }
    final address = _savedAddresses.firstWhere((item) => item.id == id);
    setState(() => _selectedSavedAddressId = id);
    _streetController.text = address.address;
    _cityController.clear();
    if (address.recipientName.isNotEmpty) {
      _nameController.text = address.recipientName;
    }
    if (address.phone.isNotEmpty) _phoneController.text = address.phone;
    checkout.setStreetBarangay(address.address);
    checkout.setCity('');
    checkout.setContactName(_nameController.text);
    checkout.setContactPhone(_phoneController.text);
  }

  void _setControllerIfEmpty(TextEditingController controller, String value) {
    if (controller.text.isEmpty && value.isNotEmpty) {
      controller.text = value;
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _continue() {
    final checkout = CheckoutState.instance;
    if (CartService.instance.items.isEmpty) {
      setState(() {});
      return;
    }
    if (checkout.fulfillmentType == FulfillmentType.delivery &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.pushNamed(context, '/checkout-payment');
  }

  @override
  Widget build(BuildContext context) {
    final checkout = CheckoutState.instance;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: checkout,
          builder: (context, _) {
            final groups = groupCartItems(CartService.instance.items);
            return Column(
              children: [
                const _CheckoutHeader(title: 'Delivery / Pickup'),
                const CheckoutStepIndicator(currentStep: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    children: [
                      if (checkout.profileError != null)
                        _MessageBanner(
                          message:
                              'Could not load profile details: ${checkout.profileError}',
                          isError: true,
                        ),
                      if (checkout.fulfillmentType == FulfillmentType.delivery)
                        _SavedAddressPicker(
                          addresses: _savedAddresses,
                          selectedId: _selectedSavedAddressId,
                          isLoading: _isLoadingSavedAddresses,
                          error: _savedAddressError,
                          onChanged: _selectSavedAddress,
                          onRetry: _loadSavedAddresses,
                        ),
                      if (groups.isEmpty)
                        const _MessageBanner(
                          message:
                              'Your cart is empty. Add products to continue.',
                          isError: true,
                        ),
                      _FulfillmentChoice(
                        selected: checkout.fulfillmentType,
                        onChanged: _changeFulfillment,
                      ),
                      if (checkout.fulfillmentType == FulfillmentType.pickup &&
                          _isLoadingPickupAddresses)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (checkout.fulfillmentType == FulfillmentType.pickup &&
                          _pickupAddressError != null)
                        _MessageBanner(
                          message: _pickupAddressError!,
                          isError: true,
                        ),
                      const SizedBox(height: 18),
                      if (checkout.fulfillmentType == FulfillmentType.delivery)
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (_selectedSavedAddressId != null)
                                _CheckoutTextField(
                                  controller: _streetController,
                                  label: 'Delivery address',
                                  hint: 'Enter the delivery address',
                                  onChanged: checkout.setStreetBarangay,
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? 'Enter your delivery address.'
                                      : null,
                                  maxLines: 3,
                                )
                              else ...[
                                _CheckoutTextField(
                                  controller: _streetController,
                                  label: 'Street / Barangay',
                                  hint: 'House number, street, barangay',
                                  onChanged: (value) {
                                    _manualStreet = value;
                                    checkout.setStreetBarangay(value);
                                  },
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? 'Enter your street and barangay.'
                                      : null,
                                ),
                                _CheckoutTextField(
                                  controller: _cityController,
                                  label: 'City',
                                  hint: 'City or municipality',
                                  onChanged: (value) {
                                    _manualCity = value;
                                    checkout.setCity(value);
                                  },
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                      ? 'Enter your city.'
                                      : null,
                                ),
                              ],
                              _CheckoutTextField(
                                controller: _notesController,
                                label: 'Delivery notes (optional)',
                                hint: 'Landmark or delivery instructions',
                                onChanged: checkout.setDeliveryNotes,
                                maxLines: 2,
                              ),
                              _CheckoutTextField(
                                controller: _nameController,
                                label: 'Contact name',
                                hint: 'Name of the person receiving',
                                onChanged: (value) {
                                  if (_selectedSavedAddressId == null) {
                                    _manualName = value;
                                  }
                                  checkout.setContactName(value);
                                },
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? 'Enter a contact name.'
                                    : null,
                              ),
                              _CheckoutTextField(
                                controller: _phoneController,
                                label: 'Contact phone',
                                hint: '09XXXXXXXXX or +639XXXXXXXXX',
                                keyboardType: TextInputType.phone,
                                onChanged: (value) {
                                  if (_selectedSavedAddressId == null) {
                                    _manualPhone = value;
                                  }
                                  checkout.setContactPhone(value);
                                },
                                validator: (value) {
                                  final phone = (value ?? '').trim();
                                  if (!RegExp(
                                    r'^(09\d{9}|\+639\d{9})$',
                                  ).hasMatch(phone)) {
                                    return 'Enter a valid Philippine mobile number.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        ...groups.values.map(
                          (items) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PickupSellerCard(
                              sellerName: items.first.product.sellerName,
                              pickupAddress:
                                  _pickupAddresses[items
                                      .first
                                      .product
                                      .sellerId],
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        checkout.fulfillmentType == FulfillmentType.delivery
                            ? 'Delivery fee by seller'
                            : 'Pickup fee by seller',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final items in groups.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _SellerFeeRow(
                            seller: items.first.product.sellerName,
                            fee:
                                checkout.fulfillmentType ==
                                    FulfillmentType.delivery
                                ? kDeliveryFeePerSeller
                                : 0,
                          ),
                        ),
                      const SizedBox(height: 6),
                      PriceSummary(
                        subtotal: checkout.subtotal,
                        deliveryFee: checkout.deliveryFee,
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Continue to Payment',
                        onPressed: groups.isEmpty ? null : _continue,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SavedAddressPicker extends StatelessWidget {
  const _SavedAddressPicker({
    required this.addresses,
    required this.selectedId,
    required this.isLoading,
    required this.error,
    required this.onChanged,
    required this.onRetry,
  });

  final List<SavedAddress> addresses;
  final String? selectedId;
  final bool isLoading;
  final String? error;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: selectedId,
            decoration: const InputDecoration(
              labelText: 'Choose saved address',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Enter address manually'),
              ),
              for (final address in addresses)
                DropdownMenuItem<String?>(
                  value: address.id,
                  child: Text(
                    '${address.label}: ${address.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: isLoading ? null : onChanged,
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (error != null)
            _MessageBanner(
              message: 'Saved addresses could not be loaded: $error',
              isError: true,
              actionLabel: 'Retry',
              onAction: onRetry,
            ),
        ],
      ),
    );
  }
}

class CheckoutPaymentScreen extends StatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  bool _isLoadingDefault = true;
  bool _userChangedPayment = false;
  String? _defaultPaymentError;

  @override
  void initState() {
    super.initState();
    _loadDefaultPayment();
  }

  Future<void> _loadDefaultPayment() async {
    try {
      final method = await BuyerAccountService.fetchDefaultPaymentMethod();
      if (!mounted) return;
      if (method != null && !_userChangedPayment) {
        CheckoutState.instance.setPaymentMethod(
          PaymentMethod.fromValue(method.methodType),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _defaultPaymentError = BuyerAccountService.errorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDefault = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = CheckoutState.instance;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: checkout,
          builder: (context, _) => Column(
            children: [
              const _CheckoutHeader(title: 'Payment'),
              const CheckoutStepIndicator(currentStep: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  children: [
                    Text(
                      'Choose a payment method',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_isLoadingDefault)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_defaultPaymentError != null)
                      _MessageBanner(
                        message:
                            'Could not load your default payment method: $_defaultPaymentError',
                        isError: true,
                      ),
                    const SizedBox(height: 12),
                    for (final method in PaymentMethod.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PaymentChoice(
                          method: method,
                          fulfillmentType: checkout.fulfillmentType,
                          selected: checkout.paymentMethod == method,
                          onTap: () {
                            _userChangedPayment = true;
                            checkout.setPaymentMethod(method);
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (checkout.paymentMethod != PaymentMethod.cod)
                      const _MessageBanner(
                        message:
                            'Demo payment: no real charge. No card details are collected or stored.',
                        isError: false,
                      ),
                    const SizedBox(height: 16),
                    PriceSummary(
                      subtotal: checkout.subtotal,
                      deliveryFee: checkout.deliveryFee,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Review Order',
                      onPressed: CartService.instance.items.isEmpty
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              '/checkout-review',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckoutReviewScreen extends StatefulWidget {
  const CheckoutReviewScreen({super.key});

  @override
  State<CheckoutReviewScreen> createState() => _CheckoutReviewScreenState();
}

class _CheckoutReviewScreenState extends State<CheckoutReviewScreen> {
  bool _isSubmitting = false;
  String? _submitError;

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;
    final checkout = CheckoutState.instance;
    final items = CartService.instance.items;
    if (items.isEmpty) {
      setState(() => _submitError = 'Your cart is empty.');
      return;
    }
    if (checkout.fulfillmentType == FulfillmentType.delivery &&
        (checkout.streetBarangay.trim().isEmpty ||
            checkout.city.trim().isEmpty ||
            checkout.contactName.trim().isEmpty ||
            !RegExp(
              r'^(09\d{9}|\+639\d{9})$',
            ).hasMatch(checkout.contactPhone.trim()))) {
      setState(() {
        _submitError =
            'Complete and check the delivery details before placing your order.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final orders = await OrderService.placeOrder(
        items: items,
        fulfillmentType: checkout.fulfillmentType,
        deliveryAddress: checkout.deliveryAddress,
        contactName: checkout.contactName.trim(),
        contactPhone: checkout.contactPhone.trim(),
        paymentMethod: checkout.paymentMethod,
        deliveryFeePerSeller: checkout.deliveryFeePerSeller,
      );
      if (orders.isEmpty) {
        throw StateError(
          'No orders were returned. Your cart has not been cleared.',
        );
      }
      CartService.instance.clear();
      checkout.clearAfterOrder();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/order-placed',
        (route) => route.isFirst,
        arguments: orders,
      );
    } catch (error) {
      if (mounted) {
        final message = OrderService.errorMessage(error);
        setState(() => _submitError = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _editDelivery() {
    Navigator.popUntil(
      context,
      (route) => route.settings.name == '/checkout-delivery',
    );
  }

  void _editPayment() {
    Navigator.popUntil(
      context,
      (route) => route.settings.name == '/checkout-payment',
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkout = CheckoutState.instance;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: checkout,
          builder: (context, _) {
            final groups = groupCartItems(CartService.instance.items);
            return Column(
              children: [
                const _CheckoutHeader(title: 'Order Review'),
                const CheckoutStepIndicator(currentStep: 3),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    children: [
                      for (final group in groups.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReviewSellerCard(items: group.value),
                        ),
                      _ReviewSection(
                        title: 'Fulfillment',
                        onEdit: _editDelivery,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkout.fulfillmentType.label,
                              style: const TextStyle(
                                color: AgriCartColors.darkGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              checkout.fulfillmentType ==
                                      FulfillmentType.delivery
                                  ? '${checkout.deliveryAddress}\n${checkout.contactName} · ${checkout.contactPhone}'
                                  : groups.values
                                        .map(
                                          (items) =>
                                              '${items.first.product.sellerName}: Seller will confirm pickup details',
                                        )
                                        .join('\n'),
                              style: const TextStyle(
                                color: AgriCartColors.mutedText,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReviewSection(
                        title: 'Payment',
                        onEdit: _editPayment,
                        child: Text(
                          checkout.paymentMethod.labelFor(
                            checkout.fulfillmentType,
                          ),
                          style: const TextStyle(
                            color: AgriCartColors.darkGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        checkout.fulfillmentType == FulfillmentType.delivery
                            ? 'Delivery fee by seller'
                            : 'Pickup fee by seller',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final items in groups.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _SellerFeeRow(
                            seller: items.first.product.sellerName,
                            fee: checkout.deliveryFeePerSeller,
                          ),
                        ),
                      const SizedBox(height: 6),
                      PriceSummary(
                        subtotal: checkout.subtotal,
                        deliveryFee: checkout.deliveryFee,
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        _MessageBanner(message: _submitError!, isError: true),
                      ],
                      if (groups.isEmpty) ...[
                        const SizedBox(height: 12),
                        const _MessageBanner(
                          message: 'Your cart is empty.',
                          isError: true,
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Place Order',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting || groups.isEmpty
                            ? null
                            : _placeOrder,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CheckoutStepIndicator extends StatelessWidget {
  const CheckoutStepIndicator({super.key, required this.currentStep});

  final int currentStep;

  static const _steps = ['Cart', 'Delivery', 'Payment', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          for (var index = 0; index < _steps.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index <= currentStep
                          ? AgriCartColors.buttonGreen
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index <= currentStep
                            ? AgriCartColors.buttonGreen
                            : AgriCartColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index <= currentStep
                            ? Colors.white
                            : AgriCartColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _steps[index],
                    maxLines: 1,
                    style: TextStyle(
                      color: index <= currentStep
                          ? AgriCartColors.darkGreen
                          : AgriCartColors.mutedText,
                      fontSize: 12,
                      fontWeight: index == currentStep
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 3, 18, 5),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: AgriCartColors.darkGreen),
          ),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentChoice extends StatelessWidget {
  const _FulfillmentChoice({required this.selected, required this.onChanged});

  final FulfillmentType selected;
  final ValueChanged<FulfillmentType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectCard(
            title: 'Delivery',
            subtitle: 'To your address',
            icon: Icons.local_shipping_outlined,
            selected: selected == FulfillmentType.delivery,
            onTap: () => onChanged(FulfillmentType.delivery),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SelectCard(
            title: 'Pickup',
            subtitle: 'Collect from seller',
            icon: Icons.storefront_outlined,
            selected: selected == FulfillmentType.pickup,
            onTap: () => onChanged(FulfillmentType.pickup),
          ),
        ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF5EC) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AgriCartColors.buttonGreen
                  : AgriCartColors.cardBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AgriCartColors.darkGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AgriCartColors.darkGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutTextField extends StatelessWidget {
  const _CheckoutTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _PickupSellerCard extends StatelessWidget {
  const _PickupSellerCard({
    required this.sellerName,
    required this.pickupAddress,
  });

  final String sellerName;
  final String? pickupAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_outlined,
            color: AgriCartColors.darkGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sellerName,
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pickup location: ${pickupAddress?.trim().isNotEmpty == true ? pickupAddress : 'Pickup details will be sent after confirmation'}',
                  style: const TextStyle(
                    color: AgriCartColors.mutedText,
                    fontSize: 12,
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

class _SellerFeeRow extends StatelessWidget {
  const _SellerFeeRow({required this.seller, required this.fee});

  final String seller;
  final double fee;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            seller,
            style: const TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          fee == 0 ? 'Free' : formatPeso(fee),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PaymentChoice extends StatelessWidget {
  const _PaymentChoice({
    required this.method,
    required this.fulfillmentType,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final FulfillmentType fulfillmentType;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (method) {
    PaymentMethod.cod => Icons.payments_outlined,
    PaymentMethod.gcash => Icons.account_balance_wallet_outlined,
    PaymentMethod.card => Icons.credit_card_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF5EC) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AgriCartColors.buttonGreen
                  : AgriCartColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(_icon, color: AgriCartColors.darkGreen),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  method.labelFor(fulfillmentType),
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AgriCartColors.buttonGreen
                    : AgriCartColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewSellerCard extends StatelessWidget {
  const _ReviewSellerCard({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final sellerTotal = items.fold<double>(
      0,
      (total, item) => total + item.product.currentPrice * item.quantityKg,
    );
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sold by ${items.first.product.sellerName}',
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.product.name} · ${_formatKg(item.quantityKg)} kg',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    formatPeso(item.product.currentPrice * item.quantityKg),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 14, color: AgriCartColors.cardBorder),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Items: ${formatPeso(sellerTotal)}',
              style: const TextStyle(
                color: AgriCartColors.darkGreen,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: AgriCartColors.darkGreen,
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.isError,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFFFE8E6) : const Color(0xFFE5F5E9);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: AgriCartColors.darkGreen,
              ),
              child: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
