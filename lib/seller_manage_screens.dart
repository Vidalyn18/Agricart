import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'models/order.dart';
import 'models/product.dart';
import 'services/product_service.dart';
import 'services/seller_service.dart';
import 'services/supabase_service.dart';
import 'utils/format_currency.dart';
import 'widgets/app_button.dart';
import 'widgets/price_summary.dart';
import 'widgets/product_image.dart';
import 'widgets/status_chip.dart';

void _showSellerError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(SupabaseService.errorMessage(error))));
}

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  ProductCategory? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ProductService.fetchSellerProducts(
        query: _query,
        category: _category,
        includeInactive: true,
      );
      if (mounted) setState(() => _products = products);
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Products')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _query = value;
                _load();
              },
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) {
                      setState(() => _category = null);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...ProductCategory.values.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() => _category = category);
                          _load();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Add Product',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  Navigator.pushNamed(context, '/seller-product-form'),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(error: _error!, onRetry: _load)
            else if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text("You haven't added any products yet"),
                ),
              )
            else
              ..._products.map(
                (product) => _ProductRow(
                  product: product,
                  onEdit: () => Navigator.pushNamed(
                    context,
                    '/seller-product-form',
                    arguments: product.id,
                  ),
                  onStock: () => Navigator.pushNamed(
                    context,
                    '/seller-update-stock',
                    arguments: product.id,
                  ),
                  onVisibilityChanged: _load,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onStock,
    required this.onVisibilityChanged,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onStock;
  final Future<void> Function() onVisibilityChanged;

  Future<void> _toggleVisibility(BuildContext context) async {
    final isHiding = product.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${isHiding ? 'Hide' : 'Show'} ${product.name}?'),
        content: const Text(
          'You can change this visibility setting again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isHiding ? 'Hide' : 'Show'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ProductService.setProductActive(product.id, !isHiding);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHiding ? 'Product hidden from buyers.' : 'Product is active.',
            ),
          ),
        );
        await onVisibilityChanged();
      }
    } catch (error) {
      if (context.mounted) _showSellerError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockKg <= 0;
    final lowStock = product.stockKg <= kLowStockThreshold;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ProductImage(imagePath: product.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(product.category.label),
                      Text('${formatPeso(product.currentPrice)}/kg'),
                      Text('Stock: ${product.stockKg} kg'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text(
                            product.isActive ? 'Active' : 'Hidden',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: product.isActive
                              ? const Color(0xFFE9F6EB)
                              : const Color(0xFFEDEDED),
                        ),
                      ),
                      if (outOfStock || lowStock)
                        Text(
                          outOfStock ? 'Out of stock' : 'Low stock',
                          style: TextStyle(
                            color: outOfStock ? Colors.red : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onStock,
                    child: const Text('Update Stock'),
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleVisibility(context),
                  icon: Icon(
                    product.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: product.isActive ? 'Hide' : 'Show',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _name = TextEditingController();
  final _subcategory = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _discount = TextEditingController();
  final _description = TextEditingController();
  ProductCategory _category = ProductCategory.vegetables;
  DateTime _harvestDate = DateTime.now();
  bool _discounted = false;
  bool _loading = false;
  bool _loadingProduct = false;
  Uint8List? _imageBytes;
  String? _existingImageUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) _loadProduct();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _subcategory,
      _price,
      _stock,
      _discount,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _loadingProduct = true);
    try {
      final product = await ProductService.fetchProduct(
        widget.productId!,
        includeInactive: true,
      );
      if (!mounted) return;
      _name.text = product.name;
      _subcategory.text = product.subcategory;
      _price.text = product.pricePerKg.toStringAsFixed(2);
      _stock.text = product.stockKg.toStringAsFixed(
        product.stockKg % 1 == 0 ? 0 : 1,
      );
      _description.text = product.description;
      _harvestDate = product.harvestDate;
      _category = product.category;
      _discounted = product.isDiscounted;
      _discount.text = product.discountPrice?.toStringAsFixed(2) ?? '';
      _existingImageUrl = product.imageUrl;
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loadingProduct = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _imageBytes = bytes);
      }
    } catch (error) {
      if (mounted) _showSellerError(context, error);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final stock = double.tryParse(_stock.text.trim());
    final discount = double.tryParse(_discount.text.trim());
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Price must be greater than 0.');
      return;
    }
    if (stock == null || stock < 0) {
      setState(() => _error = 'Stock cannot be negative.');
      return;
    }
    if (_harvestDate.isAfter(DateTime.now())) {
      setState(() => _error = 'Harvest date cannot be in the future.');
      return;
    }
    if (_discounted &&
        (discount == null || discount <= 0 || discount >= price)) {
      setState(
        () => _error =
            'Discount price must be greater than 0 and less than the regular price.',
      );
      return;
    }
    if (widget.productId == null && _imageBytes == null) {
      setState(() => _error = 'A product image is required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var imageUrl = _existingImageUrl;
      if (_imageBytes != null) {
        imageUrl = await ProductService.uploadProductImage(bytes: _imageBytes!);
      }
      final profile = await SupabaseService.fetchSellerProfile();
      final values = <String, dynamic>{
        'name': name,
        'seller_name': profile['farm_name']?.trim() ?? '',
        'category': _category.databaseValue,
        'subcategory': _subcategory.text.trim().isEmpty
            ? 'Other'
            : _subcategory.text.trim(),
        'price_per_kg': price,
        'rating': 0,
        'stock_kg': stock,
        'image_url': imageUrl,
        'description': _description.text.trim(),
        'harvest_date':
            '${_harvestDate.year.toString().padLeft(4, '0')}-${_harvestDate.month.toString().padLeft(2, '0')}-${_harvestDate.day.toString().padLeft(2, '0')}',
        'is_discounted': _discounted,
        'discount_price': _discounted ? discount : null,
      };
      if (widget.productId == null) {
        await ProductService.createProduct(values: values);
      } else {
        await ProductService.updateProduct(
          productId: widget.productId!,
          values: values,
        );
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/seller-success',
        (route) => route.settings.name == '/seller-products',
        arguments: widget.productId == null ? 'added' : 'updated',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = SupabaseService.errorMessage(error));
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProduct) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AgriCartColors.cardBorder),
              ),
              child: _imageBytes != null || _existingImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ProductImage(
                        imagePath: _existingImageUrl,
                        imageBytes: _imageBytes,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 38),
                        SizedBox(height: 8),
                        Text('Add product photo'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _Field(label: 'Name', controller: _name),
          _Field(label: 'Subcategory', controller: _subcategory),
          DropdownButtonFormField<ProductCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ProductCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Price per kg',
            controller: _price,
            keyboardType: TextInputType.number,
          ),
          _Field(
            label: 'Stock kg',
            controller: _stock,
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Discounted price'),
            value: _discounted,
            onChanged: (value) => setState(() => _discounted = value),
          ),
          if (_discounted)
            _Field(
              label: 'Discount price',
              controller: _discount,
              keyboardType: TextInputType.number,
            ),
          _Field(label: 'Description', controller: _description, maxLines: 4),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _harvestDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _harvestDate = date);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Harvest date: ${_harvestDate.year}-${_harvestDate.month.toString().padLeft(2, '0')}-${_harvestDate.day.toString().padLeft(2, '0')}',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: widget.productId == null ? 'Add Product' : 'Update Product',
            isLoading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          AppButton(label: 'Retry', onPressed: () => onRetry()),
        ],
      ),
    );
  }
}

class UpdateStockScreen extends StatefulWidget {
  const UpdateStockScreen({super.key, required this.productId});
  final String productId;

  @override
  State<UpdateStockScreen> createState() => _UpdateStockScreenState();
}

class _UpdateStockScreenState extends State<UpdateStockScreen> {
  Product? _product;
  final _stock = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final product = await ProductService.fetchProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _stock.text = product.stockKg.toStringAsFixed(
          product.stockKg % 1 == 0 ? 0 : 1,
        );
      });
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(double amount) {
    final current = double.tryParse(_stock.text) ?? 0;
    final next = current + amount;
    _stock.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
  }

  Future<void> _save() async {
    final stock = double.tryParse(_stock.text);
    if (stock == null || stock < 0) {
      setState(() => _error = 'Stock cannot be negative.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProductService.updateStock(widget.productId, stock);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/seller-success',
        (route) => route.settings.name == '/seller-products',
        arguments: 'restocked',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = SupabaseService.errorMessage(error));
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Update Stock')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            _product?.name ?? 'Product',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Current stock: ${_product?.stockKg.toStringAsFixed(1) ?? '0'} kg',
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'New stock (kg)',
            controller: _stock,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          Wrap(
            spacing: 8,
            children: [10, 25, 50]
                .map(
                  (amount) => ChoiceChip(
                    label: Text('Restock +$amount'),
                    selected: false,
                    onSelected: (_) => setState(() => _add(amount.toDouble())),
                  ),
                )
                .toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Save Stock',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class SellerSuccessScreen extends StatelessWidget {
  const SellerSuccessScreen({super.key, required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final content = switch (type) {
      'added' => (
        'Product Added',
        'Your product is now available to buyers.',
        Icons.check_circle_outline,
      ),
      'updated' => (
        'Product Updated',
        'Your product changes have been saved.',
        Icons.edit_outlined,
      ),
      'restocked' => (
        'Stock Restocked',
        'Your updated stock is saved.',
        Icons.inventory_outlined,
      ),
      _ => (
        'Product Deleted',
        'The product is no longer visible to buyers.',
        Icons.delete_outline,
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(content.$3, size: 72, color: AgriCartColors.buttonGreen),
              const SizedBox(height: 18),
              Text(
                content.$1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(content.$2, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AppButton(
                label: 'Back to Products',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/seller-products',
                  (route) => false,
                ),
              ),
              if (type == 'added') ...[
                const SizedBox(height: 10),
                AppButton(
                  label: 'Add Another',
                  outlined: true,
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/seller-product-form',
                    (route) => false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key, this.initialFilter});
  final String? initialFilter;

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const _filters = ['New', 'In Progress', 'Done'];
  late String _filter = _initialTab(widget.initialFilter);
  List<MarketplaceOrder> _orders = [];
  bool _loading = true;
  String? _error;

  static String _initialTab(String? filter) => switch (filter) {
    'In Progress' || 'Preparing' || 'Ready or Out' => 'In Progress',
    'Done' || 'Completed' || 'Cancelled' => 'Done',
    _ => 'New',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await SellerService.fetchSellerOrders();
      final filtered = all.where((order) {
        return switch (_filter) {
          'New' => order.status == OrderStatus.pending,
          'In Progress' => {
            OrderStatus.confirmed,
            OrderStatus.preparing,
            OrderStatus.outForDelivery,
            OrderStatus.readyForPickup,
          }.contains(order.status),
          'Done' =>
            order.status == OrderStatus.completed ||
                order.status == OrderStatus.cancelled,
          _ => false,
        };
      }).toList();
      if (mounted) setState(() => _orders = filtered);
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          selected: _filter == filter,
                          onSelected: (_) {
                            setState(() => _filter = filter);
                            _load();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(error: _error!, onRetry: _load)
            else if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No orders in this view')),
              )
            else
              ..._orders.map(
                (order) => Card(
                  child: ListTile(
                    title: Text(order.orderNumber),
                    subtitle: Text(
                      '${order.fulfillmentType.label} • ${order.itemCount} item(s)',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatPeso(order.total)),
                        StatusChip(status: order.status),
                      ],
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/seller-order-details',
                      arguments: order.id,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SellerOrderDetailsScreen extends StatefulWidget {
  const SellerOrderDetailsScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<SellerOrderDetailsScreen> createState() =>
      _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends State<SellerOrderDetailsScreen> {
  MarketplaceOrder? _order;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await SellerService.fetchSellerOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  OrderStatus? get _nextStatus {
    final order = _order;
    if (order == null) return null;
    return switch (order.status) {
      OrderStatus.pending => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing =>
        order.fulfillmentType == FulfillmentType.delivery
            ? OrderStatus.outForDelivery
            : OrderStatus.readyForPickup,
      OrderStatus.outForDelivery => OrderStatus.completed,
      OrderStatus.readyForPickup => OrderStatus.completed,
      _ => null,
    };
  }

  String get _nextLabel {
    return switch (_nextStatus) {
      OrderStatus.confirmed => 'Accept',
      OrderStatus.preparing => 'Start Preparing',
      OrderStatus.outForDelivery => 'Out for Delivery',
      OrderStatus.readyForPickup => 'Ready for Pickup',
      OrderStatus.completed => 'Mark Completed',
      _ => '',
    };
  }

  Future<void> _changeStatus(OrderStatus status) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SellerService.updateStatus(orderId: widget.orderId, status: status);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order status updated')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = SupabaseService.errorMessage(error));
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openDeliveryForm() async {
    final riderName = TextEditingController();
    final riderPhone = TextEditingController();
    DateTime? eta;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Out for Delivery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: riderName,
                  decoration: const InputDecoration(labelText: 'Rider name'),
                ),
                TextField(
                  controller: riderPhone,
                  decoration: const InputDecoration(labelText: 'Rider phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date == null) return;
                    if (!context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      eta = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    eta == null
                        ? 'Choose ETA'
                        : '${eta!.year}-${eta!.month.toString().padLeft(2, '0')}-${eta!.day.toString().padLeft(2, '0')} '
                              '${TimeOfDay.fromDateTime(eta!).format(context)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) {
      riderName.dispose();
      riderPhone.dispose();
      return;
    }
    if (confirmed != true) {
      riderName.dispose();
      riderPhone.dispose();
      return;
    }
    final phone = riderPhone.text.trim();
    if (riderName.text.trim().isEmpty ||
        !RegExp(r'^(09[0-9]{9}|\+639[0-9]{9})$').hasMatch(phone)) {
      const message =
          'Rider name and a valid Philippine phone number are required.';
      setState(() => _error = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
      riderName.dispose();
      riderPhone.dispose();
      return;
    }
    if (eta == null) {
      const message = 'Choose an estimated delivery time.';
      setState(() => _error = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
      riderName.dispose();
      riderPhone.dispose();
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SellerService.updateStatus(
        orderId: widget.orderId,
        status: OrderStatus.outForDelivery,
        eta: eta,
        riderName: riderName.text.trim(),
        riderPhone: phone,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order status updated')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = SupabaseService.errorMessage(error));
        _showSellerError(context, error);
      }
    } finally {
      riderName.dispose();
      riderPhone.dispose();
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _declineOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline order?'),
        content: const Text(
          'This will mark the order as cancelled. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _changeStatus(OrderStatus.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
        body: Center(
          child: _ErrorState(
            error: _error ?? 'Order not found.',
            onRetry: _load,
          ),
        ),
      );
    }
    final canDecline = order.status == OrderStatus.pending;
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            StatusChip(status: order.status),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buyer: ${order.buyerName ?? order.contactName ?? 'Buyer'}',
                    ),
                    Text('Contact: ${order.contactName ?? 'Not provided'}'),
                    if (order.contactPhone != null)
                      TextButton.icon(
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${order.contactPhone}')),
                        icon: const Icon(Icons.phone),
                        label: Text(order.contactPhone!),
                      ),
                    Text('Fulfillment: ${order.fulfillmentType.label}'),
                    Text(
                      order.fulfillmentType == FulfillmentType.delivery
                          ? order.deliveryAddress ?? 'No address'
                          : 'Buyer will pick up',
                    ),
                    Text(
                      'Payment: ${order.paymentMethod.labelFor(order.fulfillmentType)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...order.items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.productName),
                  subtitle: Text('${item.quantityKg} kg'),
                  trailing: Text(formatPeso(item.lineTotal)),
                ),
              ),
            ),
            PriceSummary(
              subtotal: order.subtotal,
              deliveryFee: order.deliveryFee,
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_nextStatus != null) ...[
              const SizedBox(height: 10),
              AppButton(
                label: _nextLabel,
                isLoading: _submitting,
                onPressed: _submitting
                    ? null
                    : () {
                        if (_nextStatus == OrderStatus.outForDelivery) {
                          _openDeliveryForm();
                        } else {
                          _changeStatus(_nextStatus!);
                        }
                      },
              ),
            ],
            if (canDecline) ...[
              const SizedBox(height: 8),
              AppButton(
                label: 'Decline',
                outlined: true,
                onPressed: _submitting ? null : _declineOrder,
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Status Timeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            ...order.statusHistory.map(
              (entry) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(entry.status.label),
                subtitle: Text(entry.createdAt.toLocal().toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerSalesScreen extends StatefulWidget {
  const SellerSalesScreen({super.key});

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  int _days = 7;
  Map<String, dynamic>? _sales;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sales = await SellerService.fetchSales(_days);
      if (mounted) setState(() => _sales = sales);
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_days},
              onSelectionChanged: (values) {
                setState(() => _days = values.first);
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(error: _error!, onRetry: _load)
            else if (_sales != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatPeso(
                          (_sales!['total_sales'] as num?)?.toDouble() ?? 0,
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed orders: ${_sales!['completed_orders'] ?? 0}',
                      ),
                      Text('Pending orders: ${_sales!['pending_orders'] ?? 0}'),
                      Text('All orders: ${_sales!['all_orders'] ?? 0}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SalesChart(sales: _sales!, days: _days),
              const SizedBox(height: 12),
              const Text(
                'Top products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if ((_sales!['top_products'] as List? ?? const []).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No sales in this period'),
                )
              else
                ...((_sales!['top_products'] as List).map((row) {
                  final map = Map<String, dynamic>.from(row as Map);
                  return ListTile(
                    title: Text(map['name'].toString()),
                    subtitle: Text(
                      '${(map['kg'] as num?)?.toStringAsFixed(1) ?? '0.0'} kg',
                    ),
                    trailing: Text(
                      formatPeso((map['sales'] as num?)?.toDouble() ?? 0),
                    ),
                  );
                })),
            ],
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.sales, required this.days});
  final Map<String, dynamic> sales;
  final int days;

  @override
  Widget build(BuildContext context) {
    final rows = Map<String, double>.fromEntries(
      ((sales['daily'] as List?) ?? const []).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final day = map['day'].toString();
        return MapEntry(
          day.length >= 10 ? day.substring(0, 10) : day,
          (map['sales'] as num?)?.toDouble() ?? 0,
        );
      }),
    );
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (var i = 0; i < days; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days - 1 - i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      spots.add(FlSpot(i.toDouble(), rows[key] ?? 0));
    }
    return SizedBox(
      height: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: days >= 90
                        ? 15
                        : days == 30
                        ? 5
                        : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= days) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      ).subtract(Duration(days: days - 1 - index));
                      return Text('${date.month}/${date.day}');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: AgriCartColors.darkGreen,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.lowStockOnly});
  final bool lowStockOnly;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _loading = true;
  bool _lowOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lowOnly = widget.lowStockOnly;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ProductService.fetchInventory(
        lowStockOnly: _lowOnly,
      );
      if (mounted) setState(() => _products = products);
    } catch (error) {
      if (mounted) {
        _error = SupabaseService.errorMessage(error);
        _showSellerError(context, error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStock(Product product) async {
    final controller = TextEditingController(
      text: product.stockKg.toStringAsFixed(product.stockKg % 1 == 0 ? 0 : 1),
    );
    String? dialogError;
    final stock = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update stock for ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Stock (kg)'),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value == null || value < 0) {
                  setDialogState(
                    () => dialogError = 'Enter a stock amount of 0 or more.',
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (stock == null || !mounted) return;
    try {
      await ProductService.updateStock(product.id, stock);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully.')),
      );
      await _load();
    } catch (error) {
      if (mounted) _showSellerError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_lowOnly ? 'Low Stock' : 'Inventory')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            ChoiceChip(
              label: const Text('Low stock'),
              selected: _lowOnly,
              onSelected: (value) {
                setState(() => _lowOnly = value);
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorState(error: _error!, onRetry: _load)
            else if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No products in this view')),
              )
            else
              ..._products.map(
                (product) => Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: ProductImage(imagePath: product.imageUrl),
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${product.stockKg} kg • '
                      '${product.stockKg <= 0
                          ? 'Out of stock'
                          : product.stockKg <= kLowStockThreshold
                          ? 'Low stock'
                          : 'In stock'}',
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => _updateStock(product),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('Update stock'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
