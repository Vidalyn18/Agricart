import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'buyer_checkout_screens.dart';
import 'buyer_order_screens.dart';
import 'buyer_profile_screens.dart';
import 'models/product.dart';
import 'services/cart_service.dart';
import 'services/product_service.dart';
import 'services/supabase_service.dart';
import 'utils/format_currency.dart';
import 'widgets/product_image.dart';

class BuyerShell extends StatefulWidget {
  const BuyerShell({
    super.key,
    required this.supabaseConfigured,
    this.initialIndex = 0,
    this.initialBody,
    this.onSignOut,
  });

  final bool supabaseConfigured;
  final int initialIndex;
  final Widget? initialBody;
  final Future<void> Function()? onSignOut;

  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _homeScreen(),
          widget.initialBody ??
              _CategoriesIndexScreen(
                onTap: (category) => Navigator.pushNamed(
                  context,
                  '/category',
                  arguments: category.databaseValue,
                ),
              ),
          CartScreen(supabaseConfigured: widget.supabaseConfigured),
          MyOrdersScreen(supabaseConfigured: widget.supabaseConfigured),
          BuyerProfileScreen(
            supabaseConfigured: widget.supabaseConfigured,
            onOpenOrders: () => setState(() => _index = 3),
            onSignOut: widget.onSignOut,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: Colors.white,
        indicatorColor: AgriCartColors.background,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: _CartNavIcon(),
            selectedIcon: _CartNavIcon(),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _homeScreen() {
    return BuyerHomeScreen(
      supabaseConfigured: widget.supabaseConfigured,
      onOpenProfile: () => setState(() => _index = 4),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined),
          if (CartService.instance.itemCount > 0)
            Positioned(
              right: -10,
              top: -7,
              child: _CountBadge(count: CartService.instance.itemCount),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AgriCartColors.buttonGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoriesIndexScreen extends StatelessWidget {
  const _CategoriesIndexScreen({required this.onTap});

  final ValueChanged<ProductCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Text('Categories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _SearchCategoryGrid(onTap: onTap),
        ],
      ),
    );
  }
}

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({
    super.key,
    required this.supabaseConfigured,
    required this.onOpenProfile,
  });

  final bool supabaseConfigured;
  final VoidCallback onOpenProfile;

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  late Future<_HomeData> _homeData = _loadHome();

  Future<_HomeData> _loadHome() async {
    if (!widget.supabaseConfigured) {
      throw StateError('Connect Supabase to browse available products.');
    }
    final productsFuture = ProductService.fetchProducts();
    final discountedFuture = ProductService.fetchProducts(discountedOnly: true);
    final fullNameFuture = SupabaseService.fetchCurrentFullName();
    final products = await productsFuture;
    final discountedProducts = await discountedFuture;
    final fullName = await fullNameFuture;
    return _HomeData(
      fullName: fullName,
      products: products,
      discountedProducts: discountedProducts,
    );
  }

  void _retry() => setState(() => _homeData = _loadHome());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _homeData,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              message: SupabaseService.errorMessage(snapshot.error!),
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) return const _LoadingState();
          final data = snapshot.data!;
          return RefreshIndicator(
            color: AgriCartColors.buttonGreen,
            onRefresh: () async => _retry(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AgriCartColors.background,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.eco_outlined,
                        color: AgriCartColors.darkGreen,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'AgriCart',
                        style: TextStyle(
                          color: AgriCartColors.darkGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: widget.onOpenProfile,
                      icon: const Icon(
                        Icons.person_outline,
                        color: AgriCartColors.darkGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Hello, ${data.fullName}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Good to see you again!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AgriCartColors.mutedText,
                  ),
                ),
                const SizedBox(height: 17),
                _SearchEntry(
                  onTap: () => Navigator.pushNamed(context, '/search'),
                ),
                const SizedBox(height: 18),
                _HeroBanner(
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/see-all',
                    arguments: 'fresh',
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeading(title: 'Shop by Category'),
                const SizedBox(height: 11),
                _CategoryRow(
                  onTap: (category) => Navigator.pushNamed(
                    context,
                    '/category',
                    arguments: category.databaseValue,
                  ),
                ),
                if (data.products.isEmpty) ...[
                  const SizedBox(height: 24),
                  const _EmptyState(
                    icon: Icons.eco_outlined,
                    title: 'No products available yet',
                    message: 'Local sellers’ fresh picks will show up here.',
                  ),
                ] else ...[
                  const SizedBox(height: 22),
                  _SectionHeading(
                    title: 'Discounted',
                    linkText: 'See All',
                    onLinkTap: () => Navigator.pushNamed(
                      context,
                      '/see-all',
                      arguments: 'discounted',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProductStrip(
                    products: data.discountedProducts.take(8).toList(),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeading(
                    title: 'Fresh Today',
                    linkText: 'See All',
                    onLinkTap: () => Navigator.pushNamed(
                      context,
                      '/see-all',
                      arguments: 'fresh',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProductStrip(products: data.freshProducts.take(8).toList()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.fullName,
    required this.products,
    required this.discountedProducts,
  });

  final String fullName;
  final List<Product> products;
  final List<Product> discountedProducts;

  List<Product> get freshProducts {
    final fresh = List<Product>.of(products);
    fresh.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
    return fresh;
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AgriCartColors.cardBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: AgriCartColors.mutedText),
            SizedBox(width: 10),
            Text(
              'Search products...',
              style: TextStyle(color: AgriCartColors.mutedText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.8,
              child: Image.network(
                'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AgriCartColors.darkGreen,
                  alignment: Alignment.centerRight,
                  child: const Icon(
                    Icons.eco,
                    size: 110,
                    color: Color(0x5588D19A),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AgriCartColors.darkGreen.withValues(alpha: 0.92),
                      AgriCartColors.darkGreen.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Fresh from local farms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Good food, grown close to home.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore picks',
                            style: TextStyle(
                              color: AgriCartColors.darkGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.onTap});

  final ValueChanged<ProductCategory> onTap;

  static const _icons = <ProductCategory, IconData>{
    ProductCategory.vegetables: Icons.spa_outlined,
    ProductCategory.fruits: Icons.apple_outlined,
    ProductCategory.riceGrains: Icons.grass_outlined,
    ProductCategory.meatSeafood: Icons.set_meal_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(82.0, (constraints.maxWidth - 24) / 4);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ProductCategory.values
              .map(
                (category) =>
                    SizedBox(width: width, child: _categoryCard(category)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _categoryCard(ProductCategory category) {
    return SizedBox(
      width: 82,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => onTap(category),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AgriCartColors.cardBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icons[category],
                    size: 25,
                    color: AgriCartColors.darkGreen,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: AgriCartColors.darkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.linkText, this.onLinkTap});

  final String title;
  final String? linkText;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (linkText != null)
          TextButton(
            onPressed: onLinkTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AgriCartColors.darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              linkText!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _ProductStrip extends StatelessWidget {
  const _ProductStrip({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No products to show yet.',
          style: TextStyle(color: AgriCartColors.mutedText, fontSize: 13),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(168.0, constraints.maxWidth * 0.46);
        final height = width / 1.5 + 164;
        return SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < products.length; index++) ...[
                  if (index > 0) const SizedBox(width: 12),
                  ProductCard(
                    product: products[index],
                    width: width,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/product',
                      arguments: products[index].id,
                    ),
                    onAdd: () => addProductToCart(context, products[index]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.showAddButton = true,
    this.fullAddButton = false,
    this.onTap,
    this.onAdd,
  });

  final Product product;
  final double? width;
  final bool showAddButton;
  final bool fullAddButton;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final price = product.currentPrice;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AgriCartColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: ProductImage(imagePath: product.imageUrl),
                  ),
                  if (product.isDiscounted)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F6EB),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'SALE',
                          style: TextStyle(
                            color: AgriCartColors.darkGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (product.stockKg <= 10)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: product.stockKg <= 0
                              ? const Color(0xFFFFEEEE)
                              : const Color(0xFFFFF3D9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          product.stockKg <= 0 ? 'Out of stock' : 'Low stock',
                          style: TextStyle(
                            color: product.stockKg <= 0
                                ? const Color(0xFF8A3030)
                                : const Color(0xFF795A16),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AgriCartColors.darkGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${formatPeso(price)} / kg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AgriCartColors.darkGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF4B942),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    if (product.isDiscounted && product.discountPrice != null)
                      Text(
                        '${formatPeso(product.pricePerKg)} / kg',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AgriCartColors.mutedText,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (showAddButton) ...[
                      const SizedBox(height: 7),
                      if (fullAddButton)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add to Cart'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              backgroundColor: AgriCartColors.buttonGreen,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Add ${product.name} to cart',
                            onPressed: onAdd,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: AgriCartColors.buttonGreen,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add, size: 20),
                          ),
                        ),
                    ],
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

void addProductToCart(BuildContext context, Product product) {
  final result = CartService.instance.addProduct(
    product,
    quantityKg: product.stockKg < 1 ? 0.5 : 1,
  );
  final message = switch (result) {
    CartAddResult.added => 'Added to cart',
    CartAddResult.stockLimit => 'Available stock limit reached.',
    CartAddResult.outOfStock => 'This product is out of stock.',
    CartAddResult.minimumQuantity => 'The minimum order is 0.5 kg.',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.category,
    required this.supabaseConfigured,
  });

  final ProductCategory category;
  final bool supabaseConfigured;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final Set<String> _selectedSubcategories = {};
  _CategorySort _sort = _CategorySort.name;
  RangeValues? _priceRange;
  double _minimumRating = 0;
  bool _inStockOnly = false;
  bool _discountOnly = false;
  late Future<List<Product>> _products = _fetch();

  Future<List<Product>> _fetch() {
    if (!widget.supabaseConfigured) {
      return Future.error(
        StateError('Connect Supabase to browse available products.'),
      );
    }
    return ProductService.fetchProducts(category: widget.category);
  }

  void _retry() => setState(() => _products = _fetch());

  int get _activeFilterCount =>
      _selectedSubcategories.length +
      (_priceRange == null ? 0 : 1) +
      (_minimumRating == 0 ? 0 : 1) +
      (_inStockOnly ? 1 : 0) +
      (_discountOnly ? 1 : 0);

  void _applySelection(_CategoryFilterSelection selection) {
    setState(() {
      _selectedSubcategories
        ..clear()
        ..addAll(selection.subcategories);
      _priceRange = selection.priceRange;
      _minimumRating = selection.minimumRating;
      _inStockOnly = selection.inStockOnly;
      _discountOnly = selection.discountOnly;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedSubcategories.clear();
      _priceRange = null;
      _minimumRating = 0;
      _inStockOnly = false;
      _discountOnly = false;
    });
  }

  Future<void> _openSortSheet() async {
    final selectedSort = await showModalBottomSheet<_CategorySort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final sort in _CategorySort.values)
              ListTile(
                minTileHeight: 48,
                title: Text(sort.label, style: const TextStyle(fontSize: 14)),
                trailing: sort == _sort
                    ? const Icon(Icons.check, color: AgriCartColors.buttonGreen)
                    : null,
                onTap: () => Navigator.pop(context, sort),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selectedSort != null && mounted) {
      setState(() => _sort = selectedSort);
    }
  }

  Future<void> _openFilterSheet(List<Product> products) async {
    if (products.isEmpty) return;
    final prices = products.map((product) => product.currentPrice).toList();
    final minimumPrice = prices.reduce(math.min);
    final maximumPrice = prices.reduce(math.max);
    final selection = await showModalBottomSheet<_CategoryFilterSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryFilterSheet(
        products: products,
        minimumPrice: minimumPrice,
        maximumPrice: maximumPrice,
        initialSelection: _CategoryFilterSelection(
          subcategories: Set<String>.of(_selectedSubcategories),
          priceRange: _priceRange,
          minimumRating: _minimumRating,
          inStockOnly: _inStockOnly,
          discountOnly: _discountOnly,
        ),
      ),
    );
    if (selection != null && mounted) _applySelection(selection);
  }

  List<Product> _visibleProducts(List<Product> products) {
    final visible = _filterCategoryProducts(
      products,
      _CategoryFilterSelection(
        subcategories: _selectedSubcategories,
        priceRange: _priceRange,
        minimumRating: _minimumRating,
        inStockOnly: _inStockOnly,
        discountOnly: _discountOnly,
      ),
    );
    switch (_sort) {
      case _CategorySort.name:
        visible.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _CategorySort.priceLowToHigh:
        visible.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
      case _CategorySort.priceHighToLow:
        visible.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
      case _CategorySort.topRated:
        visible.sort((a, b) => b.rating.compareTo(a.rating));
      case _CategorySort.freshest:
        visible.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
    }
    return visible;
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[
      for (final subcategory in _selectedSubcategories)
        InputChip(
          label: Text(subcategory, style: const TextStyle(fontSize: 12)),
          onDeleted: () =>
              setState(() => _selectedSubcategories.remove(subcategory)),
        ),
      if (_priceRange case final range?)
        InputChip(
          label: Text(
            '${formatPeso(range.start)}–${formatPeso(range.end)}',
            style: const TextStyle(fontSize: 12),
          ),
          onDeleted: () => setState(() => _priceRange = null),
        ),
      if (_minimumRating > 0)
        InputChip(
          label: Text(
            '${_minimumRating == 4.5 ? '4.5' : _minimumRating.toStringAsFixed(0)}+ stars',
            style: const TextStyle(fontSize: 12),
          ),
          onDeleted: () => setState(() => _minimumRating = 0),
        ),
      if (_inStockOnly)
        InputChip(
          label: const Text('In stock', style: TextStyle(fontSize: 12)),
          onDeleted: () => setState(() => _inStockOnly = false),
        ),
      if (_discountOnly)
        InputChip(
          label: const Text('On discount', style: TextStyle(fontSize: 12)),
          onDeleted: () => setState(() => _discountOnly = false),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: chips,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Product>>(
        future: _products,
        builder: (context, snapshot) {
          final allProducts = snapshot.data;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 2, 10, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AgriCartColors.darkGreen,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.category.label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sort',
                      onPressed: _openSortSheet,
                      icon: const Icon(Icons.sort),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Filter',
                      onPressed: allProducts == null
                          ? null
                          : () => _openFilterSheet(allProducts),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.tune),
                          if (_activeFilterCount > 0)
                            Positioned(
                              right: -9,
                              top: -8,
                              child: _FilterCountBadge(
                                count: _activeFilterCount,
                              ),
                            ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActiveFilterChips(),
              Expanded(
                child: snapshot.hasError
                    ? _ErrorState(
                        message: SupabaseService.errorMessage(snapshot.error!),
                        onRetry: _retry,
                      )
                    : allProducts == null
                    ? const _LoadingState()
                    : _buildProductResults(allProducts),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductResults(List<Product> allProducts) {
    final products = _visibleProducts(allProducts);
    if (products.isEmpty) {
      final hasFilters = _activeFilterCount > 0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_outlined,
                size: 48,
                color: AgriCartColors.buttonGreen,
              ),
              const SizedBox(height: 10),
              Text(
                hasFilters
                    ? 'No products match these filters'
                    : 'No products yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                hasFilters
                    ? 'Adjust or clear your filters to see more products.'
                    : 'Check back soon for fresh local produce.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AgriCartColors.mutedText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: AgriCartColors.darkGreen,
                ),
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 9),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${products.length} ${products.length == 1 ? 'product' : 'products'}',
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) => ProductCard(
                  product: products[index],
                  width: constraints.maxWidth,
                  showAddButton: false,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/product',
                    arguments: products[index].id,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _CategorySort {
  name('Default (name A-Z)'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  topRated('Top Rated'),
  freshest('Freshest');

  const _CategorySort(this.label);

  final String label;
}

class _CategoryFilterSelection {
  const _CategoryFilterSelection({
    required this.subcategories,
    required this.priceRange,
    required this.minimumRating,
    required this.inStockOnly,
    required this.discountOnly,
  });

  final Set<String> subcategories;
  final RangeValues? priceRange;
  final double minimumRating;
  final bool inStockOnly;
  final bool discountOnly;
}

List<Product> _filterCategoryProducts(
  List<Product> products,
  _CategoryFilterSelection selection,
) {
  return products.where((product) {
    if (selection.subcategories.isNotEmpty &&
        !selection.subcategories.contains(product.subcategory)) {
      return false;
    }
    final range = selection.priceRange;
    if (range != null &&
        (product.currentPrice < range.start ||
            product.currentPrice > range.end)) {
      return false;
    }
    if (product.rating < selection.minimumRating) return false;
    if (selection.inStockOnly && product.stockKg <= 0) return false;
    if (selection.discountOnly && !product.isDiscounted) return false;
    return true;
  }).toList();
}

class _CategoryFilterSheet extends StatefulWidget {
  const _CategoryFilterSheet({
    required this.products,
    required this.minimumPrice,
    required this.maximumPrice,
    required this.initialSelection,
  });

  final List<Product> products;
  final double minimumPrice;
  final double maximumPrice;
  final _CategoryFilterSelection initialSelection;

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late Set<String> _subcategories;
  late RangeValues _priceRange;
  late double _minimumRating;
  late bool _inStockOnly;
  late bool _discountOnly;

  double get _sliderMaximum => widget.maximumPrice > widget.minimumPrice
      ? widget.maximumPrice
      : widget.minimumPrice + 1;

  List<String> get _availableSubcategories =>
      widget.products.map((product) => product.subcategory).toSet().toList()
        ..sort();

  @override
  void initState() {
    super.initState();
    final selectedRange = widget.initialSelection.priceRange;
    _subcategories = Set<String>.of(widget.initialSelection.subcategories);
    _priceRange =
        selectedRange ?? RangeValues(widget.minimumPrice, _sliderMaximum);
    _minimumRating = widget.initialSelection.minimumRating;
    _inStockOnly = widget.initialSelection.inStockOnly;
    _discountOnly = widget.initialSelection.discountOnly;
  }

  _CategoryFilterSelection get _currentSelection => _CategoryFilterSelection(
    subcategories: _subcategories,
    priceRange: _priceRange,
    minimumRating: _minimumRating,
    inStockOnly: _inStockOnly,
    discountOnly: _discountOnly,
  );

  int get _matchingCount =>
      _filterCategoryProducts(widget.products, _currentSelection).length;

  void _reset() {
    setState(() {
      _subcategories.clear();
      _priceRange = RangeValues(widget.minimumPrice, _sliderMaximum);
      _minimumRating = 0;
      _inStockOnly = false;
      _discountOnly = false;
    });
  }

  void _apply() {
    final fullRange =
        _priceRange.start <= widget.minimumPrice + 0.001 &&
        _priceRange.end >= widget.maximumPrice - 0.001;
    Navigator.pop(
      context,
      _CategoryFilterSelection(
        subcategories: Set<String>.of(_subcategories),
        priceRange: fullRange ? null : _priceRange,
        minimumRating: _minimumRating,
        inStockOnly: _inStockOnly,
        discountOnly: _discountOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filter products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subcategory',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableSubcategories.map((subcategory) {
                          return FilterChip(
                            label: Text(
                              subcategory,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _subcategories.contains(subcategory),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _subcategories.add(subcategory);
                              } else {
                                _subcategories.remove(subcategory);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Price range',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${formatPeso(_priceRange.start)} – ${formatPeso(_priceRange.end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      RangeSlider(
                        min: widget.minimumPrice,
                        max: _sliderMaximum,
                        divisions: 100,
                        labels: RangeLabels(
                          formatPeso(_priceRange.start),
                          formatPeso(_priceRange.end),
                        ),
                        values: _priceRange,
                        onChanged: (range) =>
                            setState(() => _priceRange = range),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Minimum rating',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [0.0, 3.0, 4.0, 4.5].map((rating) {
                          final label = rating == 0
                              ? 'Any'
                              : '${rating == 4.5 ? '4.5' : rating.toStringAsFixed(0)}+';
                          return ChoiceChip(
                            label: Text(
                              label,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _minimumRating == rating,
                            onSelected: (_) =>
                                setState(() => _minimumRating = rating),
                          );
                        }).toList(),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'In stock only',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _inStockOnly,
                        onChanged: (value) =>
                            setState(() => _inStockOnly = value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'On discount only',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _discountOnly,
                        onChanged: (value) =>
                            setState(() => _discountOnly = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 46),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(44, 46),
                        backgroundColor: AgriCartColors.buttonGreen,
                      ),
                      child: Text('Apply ($_matchingCount)'),
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

class _FilterCountBadge extends StatelessWidget {
  const _FilterCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AgriCartColors.buttonGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 2, 18, 7),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: AgriCartColors.darkGreen),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _recentKey = 'agricart_recent_searches';
  final _controller = TextEditingController();
  List<String> _recentSearches = [];
  late Future<List<Product>> _recommended = _fetchRecommended();

  Future<List<Product>> _fetchRecommended() {
    if (!widget.supabaseConfigured) {
      return Future.error(
        StateError('Connect Supabase to browse available products.'),
      );
    }
    return ProductService.fetchProducts(limit: 8);
  }

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = preferences.getStringList(_recentKey) ?? [];
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final recent = preferences.getStringList(_recentKey) ?? [];
    recent.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    recent.insert(0, query);
    await preferences.setStringList(_recentKey, recent.take(8).toList());
    if (!mounted) return;
    Navigator.pushNamed(context, '/search-results', arguments: query);
  }

  Future<void> _clearRecent() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_recentKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Search',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: () => _search(_controller.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'Recent searches',
                linkText: 'Clear all',
                onLinkTap: _clearRecent,
              ),
              const SizedBox(height: 5),
              ..._recentSearches.map(
                (search) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.history,
                    color: AgriCartColors.mutedText,
                  ),
                  title: Text(search, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.north_west, size: 18),
                  onTap: () {
                    _controller.text = search;
                    _search(search);
                  },
                  minVerticalPadding: 8,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _SectionHeading(title: 'Shop by category'),
            const SizedBox(height: 10),
            _SearchCategoryGrid(
              onTap: (category) => Navigator.pushNamed(
                context,
                '/category',
                arguments: category.databaseValue,
              ),
            ),
            const SizedBox(height: 22),
            _SectionHeading(title: 'Popular searches'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Tomato', 'Mango', 'Pechay', 'Rice', 'Bangus']
                  .map(
                    (term) => ActionChip(
                      label: Text(term, style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onPressed: () {
                        _controller.text = term;
                        _search(term);
                      },
                      side: const BorderSide(color: AgriCartColors.cardBorder),
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 23),
            _SectionHeading(
              title: 'Recommended for you',
              linkText: 'See All',
              onLinkTap: () =>
                  Navigator.pushNamed(context, '/see-all', arguments: 'fresh'),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Product>>(
              future: _recommended,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _InlineError(
                    message: SupabaseService.errorMessage(snapshot.error!),
                    onRetry: () =>
                        setState(() => _recommended = _fetchRecommended()),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AgriCartColors.buttonGreen,
                      ),
                    ),
                  );
                }
                return _ProductStrip(products: snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCategoryGrid extends StatelessWidget {
  const _SearchCategoryGrid({required this.onTap});

  final ValueChanged<ProductCategory> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: ProductCategory.values.map((category) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 45) / 2,
            child: OutlinedButton.icon(
              onPressed: () => onTap(category),
              icon: const Icon(Icons.eco_outlined, size: 18),
              label: Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: AgriCartColors.darkGreen,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AgriCartColors.cardBorder),
                minimumSize: const Size(44, 48),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    required this.supabaseConfigured,
  });

  final String initialQuery;
  final bool supabaseConfigured;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;
  late String _query = widget.initialQuery.trim();
  String _subcategory = 'All';
  ProductSort _sort = ProductSort.recommended;
  late Future<List<Product>> _products = _fetch();

  Future<List<Product>> _fetch() {
    if (!widget.supabaseConfigured) {
      return Future.error(
        StateError('Connect Supabase to search available products.'),
      );
    }
    if (_query.isEmpty) return Future.value([]);
    return ProductService.fetchProducts(query: _query, sort: _sort);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _subcategory = 'All';
        _products = _fetch();
      });
    });
  }

  void _reload() => setState(() => _products = _fetch());

  void _setSort(ProductSort? sort) {
    if (sort == null) return;
    setState(() {
      _sort = sort;
      _products = _fetch();
    });
  }

  Future<void> _openFilter(List<String> subcategories) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter products',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: ['All', ...subcategories].map((category) {
                  return ChoiceChip(
                    label: Text(category, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    selected: _subcategory == category,
                    onSelected: (_) => Navigator.pop(context, category),
                  );
                }).toList(),
              ),
              const SizedBox(height: 15),
              const Text(
                'Choose a sort order from the dropdown on the results page.',
                style: TextStyle(fontSize: 13, color: AgriCartColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      setState(() => _subcategory = selection);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _products,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: SupabaseService.errorMessage(snapshot.error!),
                      onRetry: _reload,
                    );
                  }
                  if (!snapshot.hasData) return const _LoadingState();
                  final allProducts = snapshot.data!;
                  final subcategories =
                      allProducts
                          .map((product) => product.subcategory)
                          .toSet()
                          .toList()
                        ..sort();
                  final filtered = allProducts
                      .where(
                        (product) =>
                            _subcategory == 'All' ||
                            product.subcategory == _subcategory,
                      )
                      .toList();
                  _sortProducts(filtered, _sort);
                  if (allProducts.isEmpty) {
                    return _NoResultsState(
                      query: _query,
                      onBrowse: () => Navigator.pushNamed(
                        context,
                        '/category',
                        arguments: ProductCategory.vegetables,
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                    children: [
                      Text(
                        'Results for "$_query"',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${filtered.length} ${filtered.length == 1 ? 'product' : 'products'} found',
                        style: const TextStyle(
                          color: AgriCartColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openFilter(subcategories),
                            icon: const Icon(Icons.tune, size: 17),
                            label: const Text('Filter & Sort'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor: AgriCartColors.darkGreen,
                              side: const BorderSide(
                                color: AgriCartColors.cardBorder,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<ProductSort>(
                            value: _sort,
                            underline: const SizedBox.shrink(),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items: const [
                              DropdownMenuItem(
                                value: ProductSort.recommended,
                                child: Text('Recommended'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.priceLowHigh,
                                child: Text('Price low-high'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.priceHighLow,
                                child: Text('Price high-low'),
                              ),
                              DropdownMenuItem(
                                value: ProductSort.rating,
                                child: Text('Rating'),
                              ),
                            ],
                            onChanged: _setSort,
                          ),
                        ],
                      ),
                      if (subcategories.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', ...subcategories]
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(right: 7),
                                    child: ChoiceChip(
                                      label: Text(
                                        item,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      selected: _subcategory == item,
                                      onSelected: (_) =>
                                          setState(() => _subcategory = item),
                                      selectedColor: const Color(0xFFE3F2E6),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        const _EmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No matches in this filter',
                          message:
                              'Choose another subcategory to see products.',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: filtered
                                  .map(
                                    (product) => ProductCard(
                                      product: product,
                                      width: width,
                                      fullAddButton: true,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/product',
                                        arguments: product.id,
                                      ),
                                      onAdd: () =>
                                          addProductToCart(context, product),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
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

void _sortProducts(List<Product> products, ProductSort sort) {
  switch (sort) {
    case ProductSort.recommended:
    case ProductSort.rating:
      products.sort((a, b) => b.rating.compareTo(a.rating));
    case ProductSort.priceLowHigh:
      products.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
    case ProductSort.priceHighLow:
      products.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query, required this.onBrowse});

  final String query;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 58,
              color: AgriCartColors.buttonGreen,
            ),
            const SizedBox(height: 14),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              'We couldn’t find “$query”. Try another search or browse a category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 15),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                minimumSize: const Size(170, 46),
                backgroundColor: AgriCartColors.buttonGreen,
              ),
              child: const Text('Browse categories'),
            ),
          ],
        ),
      ),
    );
  }
}

class SeeAllProductsScreen extends StatefulWidget {
  const SeeAllProductsScreen({
    super.key,
    required this.type,
    required this.supabaseConfigured,
  });

  final String type;
  final bool supabaseConfigured;

  @override
  State<SeeAllProductsScreen> createState() => _SeeAllProductsScreenState();
}

class _SeeAllProductsScreenState extends State<SeeAllProductsScreen> {
  late Future<List<Product>> _products = _fetch();

  Future<List<Product>> _fetch() async {
    if (!widget.supabaseConfigured) {
      throw StateError('Connect Supabase to browse available products.');
    }
    final products = await ProductService.fetchProducts(
      discountedOnly: widget.type == 'discounted',
    );
    if (widget.type == 'fresh') {
      products.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'discounted'
        ? 'Discounted Picks'
        : 'Fresh Picks';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(title: title),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: _products,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: SupabaseService.errorMessage(snapshot.error!),
                      onRetry: () => setState(() => _products = _fetch()),
                    );
                  }
                  if (!snapshot.hasData) return const _LoadingState();
                  if (snapshot.data!.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.local_offer_outlined,
                      title: 'No picks available',
                      message: 'New local products will appear here soon.',
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 42) / 2;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: snapshot.data!
                                .map(
                                  (product) => ProductCard(
                                    product: product,
                                    width: width,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/product',
                                      arguments: product.id,
                                    ),
                                    onAdd: () =>
                                        addProductToCart(context, product),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      );
                    },
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

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.supabaseConfigured,
  });

  final String productId;
  final bool supabaseConfigured;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  double _quantityKg = 0.5;
  late Future<Product> _product = _fetch();
  Future<List<Product>>? _related;

  Future<Product> _fetch() {
    if (!widget.supabaseConfigured) {
      return Future.error(
        StateError('Connect Supabase to view product details.'),
      );
    }
    return ProductService.fetchProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Product>(
          future: _product,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: SupabaseService.errorMessage(snapshot.error!),
                onRetry: () => setState(() => _product = _fetch()),
              );
            }
            if (!snapshot.hasData) return const _LoadingState();
            final product = snapshot.data!;
            _related ??= ProductService.fetchRelatedProducts(product);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1.15,
                            child: ProductImage(imagePath: product.imageUrl),
                          ),
                          Positioned(
                            top: 8,
                            left: 10,
                            child: _CircleAction(
                              icon: Icons.arrow_back,
                              label: 'Back',
                              onTap: () => Navigator.maybePop(context),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFF4B942),
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.rating.toStringAsFixed(1)}  (Local reviews)',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${formatPeso(product.currentPrice)} / kg',
                                      style: const TextStyle(
                                        color: AgriCartColors.darkGreen,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (product.isDiscounted &&
                                        product.discountPrice != null)
                                      Text(
                                        '${formatPeso(product.pricePerKg)} / kg',
                                        style: const TextStyle(
                                          color: AgriCartColors.mutedText,
                                          fontSize: 12,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: [
                                _InfoChip(
                                  label: 'Freshly Harvested',
                                  icon: Icons.spa_outlined,
                                ),
                                _InfoChip(
                                  label: 'Locally Grown',
                                  icon: Icons.location_on_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _DetailInfoCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'Available Stock',
                              detail: product.stockKg <= 0
                                  ? 'Out of stock'
                                  : '${_formatQuantity(product.stockKg)} kg available',
                            ),
                            const SizedBox(height: 10),
                            _DetailInfoCard(
                              icon: Icons.storefront_outlined,
                              title: 'Sold by',
                              detail: product.sellerName,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Product Description',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              product.description.isEmpty
                                  ? 'Fresh produce sourced from a local seller.'
                                  : product.description,
                              style: const TextStyle(
                                color: AgriCartColors.mutedText,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Why You’ll Love It',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            const _BenefitRow(
                              icon: Icons.eco_outlined,
                              text: 'Fresh and carefully selected',
                            ),
                            const _BenefitRow(
                              icon: Icons.favorite_border,
                              text: 'Supports local sellers',
                            ),
                            const _BenefitRow(
                              icon: Icons.restaurant_outlined,
                              text: 'Great for everyday meals',
                            ),
                            const SizedBox(height: 12),
                            _DetailInfoCard(
                              icon: Icons.calendar_month_outlined,
                              title: 'Harvest Date',
                              detail:
                                  '${product.harvestDate.day}/${product.harvestDate.month}/${product.harvestDate.year} · ${_daysAgo(product.harvestDate)}',
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'You Might Also Like',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<Product>>(
                              future: _related,
                              builder: (context, relatedSnapshot) {
                                if (relatedSnapshot.hasError) {
                                  return _InlineError(
                                    message: SupabaseService.errorMessage(
                                      relatedSnapshot.error!,
                                    ),
                                    onRetry: () => setState(
                                      () => _related =
                                          ProductService.fetchRelatedProducts(
                                            product,
                                          ),
                                    ),
                                  );
                                }
                                if (!relatedSnapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AgriCartColors.buttonGreen,
                                      ),
                                    ),
                                  );
                                }
                                return _ProductStrip(
                                  products: relatedSnapshot.data!
                                      .take(8)
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _ProductDetailBottomBar(
                  product: product,
                  quantityKg: _quantityKg,
                  onQuantityChanged: (value) =>
                      setState(() => _quantityKg = value),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, color: AgriCartColors.darkGreen),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AgriCartColors.darkGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AgriCartColors.darkGreen),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AgriCartColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AgriCartColors.darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5EC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AgriCartColors.darkGreen),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ProductDetailBottomBar extends StatelessWidget {
  const _ProductDetailBottomBar({
    required this.product,
    required this.quantityKg,
    required this.onQuantityChanged,
  });

  final Product product;
  final double quantityKg;
  final ValueChanged<double> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: CartService.instance,
        builder: (context, _) {
          final remaining =
              (product.stockKg -
                      CartService.instance.quantityForProduct(product.id))
                  .clamp(0, product.stockKg)
                  .toDouble();
          final canAdd = product.stockKg >= 0.5 && remaining >= 0.5;
          final maxKg = remaining;
          final quantity = canAdd
              ? quantityKg.clamp(0.5, maxKg).toDouble()
              : 0.0;
          if (canAdd && quantity != quantityKg) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onQuantityChanged(quantity);
            });
          }
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AgriCartColors.cardBorder, width: 0.7),
              ),
            ),
            child: Row(
              children: [
                _QuantityStepper(
                  quantity: canAdd ? quantity : 0.5,
                  enabled: canAdd,
                  onChange: onQuantityChanged,
                  max: maxKg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: canAdd
                        ? () {
                            final result = CartService.instance.addProduct(
                              product,
                              quantityKg: quantity,
                            );
                            final message = result == CartAddResult.added
                                ? 'Added to cart'
                                : 'Available stock limit reached.';
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(message)));
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      backgroundColor: AgriCartColors.buttonGreen,
                      disabledBackgroundColor: const Color(0xFFB8C6BA),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      product.stockKg <= 0
                          ? 'Out of stock'
                          : product.stockKg < 0.5
                          ? 'Minimum 0.5 kg'
                          : remaining < 0.5
                          ? 'Stock limit reached'
                          : 'Add to Cart · ${formatPeso(product.currentPrice * quantity)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onChange,
    required this.max,
  });

  final double quantity;
  final bool enabled;
  final ValueChanged<double> onChange;
  final double max;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AgriCartColors.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: enabled && quantity > 0.5
                ? () => onChange(quantity - 0.5)
                : null,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text(
            '${_formatQuantity(quantity)} kg',
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: enabled && quantity < max
                ? () => onChange((quantity + 0.5).clamp(0.5, max).toDouble())
                : null,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _daysAgo(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final harvest = DateUtils.dateOnly(date);
  final days = math.max(0, today.difference(harvest).inDays);
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AgriCartColors.buttonGreen),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: AgriCartColors.buttonGreen,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 44),
                foregroundColor: AgriCartColors.darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message, style: const TextStyle(fontSize: 13)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AgriCartColors.buttonGreen),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
