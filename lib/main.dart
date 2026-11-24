import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'buyer_checkout_screens.dart';
import 'buyer_order_screens.dart';
import 'buyer_route_guard.dart';
import 'buyer_browse_screens.dart';
import 'login_screens.dart';
import 'seller_route_guard.dart';
import 'seller_screens.dart';
import 'seller_manage_screens.dart';
import 'models/order.dart';
import 'models/product.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = jsonDecode(await _loadSupabaseConfig());
  if (config is! Map<String, dynamic>) {
    throw const FormatException(
      'assets/config/supabase.json must contain a JSON object.',
    );
  }
  final url = config['url']?.toString() ?? '';
  final anonKey = config['anonKey']?.toString() ?? '';
  final isConfigured =
      url.startsWith('https://') &&
      anonKey.isNotEmpty &&
      !anonKey.startsWith('PASTE_');
  if (isConfigured) {
    await Supabase.initialize(url: url, publishableKey: anonKey);
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('agricart_remember_me') == false) {
      await Supabase.instance.client.auth.signOut();
    }
  }
  runApp(MyApp(supabaseConfigured: isConfigured));
}

Future<String> _loadSupabaseConfig() async {
  try {
    return await rootBundle.loadString('assets/config/supabase.json');
  } on FlutterError {
    return rootBundle.loadString('assets/config/supabase.example.json');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.latoTextTheme();
    return MaterialApp(
      title: 'AgriCart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AgriCartColors.buttonGreen,
          primary: AgriCartColors.buttonGreen,
          surface: AgriCartColors.background,
        ),
        scaffoldBackgroundColor: AgriCartColors.background,
        textTheme: baseTextTheme.copyWith(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AgriCartColors.darkGreen,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AgriCartColors.darkGreen,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AgriCartColors.darkGreen,
          ),
          titleMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AgriCartColors.darkGreen,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AgriCartColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AgriCartColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AgriCartColors.buttonGreen,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
      home: SharedStartFlow(supabaseConfigured: supabaseConfigured),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) return null;
    switch (settings.name) {
      case '/seller-home':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(
            SellerShell(
              supabaseConfigured: supabaseConfigured,
              onSignOut: () async {
                if (supabaseConfigured) await SupabaseService.signOut();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ),
        );
      case '/seller-products':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(const ManageProductsScreen()),
        );
      case '/seller-product-form':
        final productId = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              _sellerGuard(ProductFormScreen(productId: productId)),
        );
      case '/seller-update-stock':
        final productId = settings.arguments;
        if (productId is! String) return _invalidRoute(settings, 'product id');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              _sellerGuard(UpdateStockScreen(productId: productId)),
        );
      case '/seller-success':
        final type = settings.arguments;
        if (type is! String) return _invalidRoute(settings, 'success type');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(SellerSuccessScreen(type: type)),
        );
      case '/seller-orders':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(
            SellerOrdersScreen(initialFilter: settings.arguments as String?),
          ),
        );
      case '/seller-order-details':
        final orderId = settings.arguments;
        if (orderId is! String) return _invalidRoute(settings, 'order id');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              _sellerGuard(SellerOrderDetailsScreen(orderId: orderId)),
        );
      case '/seller-sales':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(const SellerSalesScreen()),
        );
      case '/seller-inventory':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _sellerGuard(
            InventoryScreen(lowStockOnly: settings.arguments == true),
          ),
        );
      case '/home':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(_buyerShell(context, initialIndex: 0)),
        );
      case '/category':
        final category = settings.arguments is ProductCategory
            ? settings.arguments as ProductCategory
            : ProductCategory.fromValue(settings.arguments);
        if (category == null) return _invalidRoute(settings, 'category');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            _buyerShell(
              context,
              initialIndex: 1,
              initialBody: CategoryScreen(
                category: category,
                supabaseConfigured: supabaseConfigured,
              ),
            ),
          ),
        );
      case '/search':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              _guard(SearchScreen(supabaseConfigured: supabaseConfigured)),
        );
      case '/search-results':
        final query = settings.arguments;
        if (query is! String) return _invalidRoute(settings, 'query');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            SearchResultsScreen(
              initialQuery: query,
              supabaseConfigured: supabaseConfigured,
            ),
          ),
        );
      case '/see-all':
        final type = settings.arguments;
        if (type is! String || (type != 'fresh' && type != 'discounted')) {
          return _invalidRoute(settings, 'fresh or discounted');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            SeeAllProductsScreen(
              type: type,
              supabaseConfigured: supabaseConfigured,
            ),
          ),
        );
      case '/product':
        final productId = settings.arguments;
        if (productId is! String || productId.isEmpty) {
          return _invalidRoute(settings, 'product id');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            ProductDetailsScreen(
              productId: productId,
              supabaseConfigured: supabaseConfigured,
            ),
          ),
        );
      case '/cart':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(_buyerShell(context, initialIndex: 2)),
        );
      case '/orders':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(_buyerShell(context, initialIndex: 3)),
        );
      case '/checkout-delivery':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(const CheckoutDeliveryScreen()),
        );
      case '/checkout-payment':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(const CheckoutPaymentScreen()),
        );
      case '/checkout-review':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(const CheckoutReviewScreen()),
        );
      case '/order-placed':
        final orders = settings.arguments;
        if (orders is! List<PlacedOrder> || orders.isEmpty) {
          return _invalidRoute(settings, 'placed order list');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(OrderPlacedScreen(orders: orders)),
        );
      case '/order-details':
        final orderId = settings.arguments;
        if (orderId is! String || orderId.isEmpty) {
          return _invalidRoute(settings, 'order id');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            OrderDetailsScreen(
              orderId: orderId,
              supabaseConfigured: supabaseConfigured,
            ),
          ),
        );
      case '/order-tracking':
        final orderId = settings.arguments;
        if (orderId is! String || orderId.isEmpty) {
          return _invalidRoute(settings, 'order id');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => _guard(
            OrderTrackingScreen(
              orderId: orderId,
              supabaseConfigured: supabaseConfigured,
            ),
          ),
        );
      default:
        return _invalidRoute(settings, 'route');
    }
  }

  Widget _guard(Widget child) {
    return BuyerRouteGuard(
      supabaseConfigured: supabaseConfigured,
      child: child,
    );
  }

  Widget _sellerGuard(Widget child) {
    return SellerRouteGuard(
      supabaseConfigured: supabaseConfigured,
      child: child,
    );
  }

  Widget _buyerShell(
    BuildContext context, {
    int initialIndex = 0,
    Widget? initialBody,
  }) {
    return BuyerShell(
      supabaseConfigured: supabaseConfigured,
      initialIndex: initialIndex,
      initialBody: initialBody,
      onSignOut: () async {
        if (supabaseConfigured) await SupabaseService.signOut();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
    );
  }

  Route<dynamic> _invalidRoute(RouteSettings settings, String argument) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 10),
                  Text('Cannot open this screen: missing $argument.'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('Go back'),
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
