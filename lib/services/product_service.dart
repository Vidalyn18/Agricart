import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

enum ProductSort { recommended, priceLowHigh, priceHighLow, rating }

class ProductService {
  ProductService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Product>> fetchProducts({
    ProductCategory? category,
    String? query,
    String? subcategory,
    bool discountedOnly = false,
    ProductSort sort = ProductSort.recommended,
    int? limit,
  }) async {
    var request = _client.from('products').select().eq('is_active', true);
    if (category != null) {
      request = request.eq('category', category.databaseValue);
    }

    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    if (subcategory != null && subcategory != 'All') {
      request = request.eq('subcategory', subcategory);
    }
    if (discountedOnly) {
      request = request.eq('is_discounted', true);
    }

    final rows = await request;
    final products = rows
        .map((row) => Product.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    _sort(products, sort);
    return limit == null ? products : products.take(limit).toList();
  }

  static Future<Product> fetchProduct(
    String id, {
    bool includeInactive = false,
  }) async {
    var request = _client.from('products').select().eq('id', id);
    if (!includeInactive) {
      request = request.eq('is_active', true);
    }
    final row = await request.maybeSingle();
    if (row == null) {
      throw StateError('This product is no longer available.');
    }
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<List<Product>> fetchSellerProducts({
    String? query,
    ProductCategory? category,
    bool includeInactive = false,
  }) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw const AuthException('Sign in as a Seller.');
    var request = _client.from('products').select().eq('seller_id', sellerId);
    if (!includeInactive) {
      request = request.eq('is_active', true);
    }
    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    if (category != null) {
      request = request.eq('category', category.databaseValue);
    }
    final rows = await request.order('stock_kg');
    return rows
        .map((row) => Product.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<List<Product>> fetchInventory({
    bool lowStockOnly = false,
  }) async {
    final products = await fetchSellerProducts();
    if (!lowStockOnly) return products;
    return products.where((product) => product.stockKg <= 10).toList();
  }

  static Future<String> uploadProductImage({required Uint8List bytes}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Sign in as a Seller.');
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  static Future<Product> createProduct({
    required Map<String, dynamic> values,
  }) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw const AuthException('Sign in as a Seller.');
    final row = await _client
        .from('products')
        .insert({...values, 'seller_id': sellerId, 'is_active': true})
        .select()
        .single();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<Product> updateProduct({
    required String productId,
    required Map<String, dynamic> values,
  }) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw const AuthException('Sign in as a Seller.');
    final row = await _client
        .from('products')
        .update({
          ...values,
          'seller_id': sellerId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId)
        .select()
        .single();
    return Product.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> updateStock(String productId, double stockKg) async {
    await _client
        .from('products')
        .update({
          'stock_kg': stockKg,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  static Future<void> setProductActive(String productId, bool isActive) async {
    await _client
        .from('products')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  static Future<void> softDeleteProduct(String productId) async {
    final activeRows = await _client
        .from('order_items')
        .select('order_id, orders!inner(status)')
        .eq('product_id', productId);
    if (activeRows.isNotEmpty) {
      final blocked = activeRows.any((row) {
        final order = row['orders'];
        if (order is Map) {
          final status = order['status']?.toString();
          return const [
            'pending',
            'confirmed',
            'preparing',
            'out_for_delivery',
            'ready_for_pickup',
          ].contains(status);
        }
        return false;
      });
      if (blocked) {
        throw StateError(
          'This product is in an active order and cannot be deleted yet.',
        );
      }
    }
    await _client
        .from('products')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  static Future<List<Product>> fetchRelatedProducts(Product product) {
    return fetchProducts(category: product.category, limit: 12).then(
      (products) => products.where((item) => item.id != product.id).toList(),
    );
  }

  static void _sort(List<Product> products, ProductSort sort) {
    switch (sort) {
      case ProductSort.recommended:
        products.sort((a, b) => b.rating.compareTo(a.rating));
      case ProductSort.priceLowHigh:
        products.sort((a, b) => a.currentPrice.compareTo(b.currentPrice));
      case ProductSort.priceHighLow:
        products.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
      case ProductSort.rating:
        products.sort((a, b) => b.rating.compareTo(a.rating));
    }
  }
}
