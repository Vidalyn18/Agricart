enum ProductCategory {
  vegetables('vegetables', 'Vegetables'),
  fruits('fruits', 'Fruits'),
  riceGrains('rice_grains', 'Rice & Grains'),
  meatSeafood('meat_seafood', 'Meat & Seafood');

  const ProductCategory(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ProductCategory? fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final category in values) {
      if (category.databaseValue == normalized ||
          category.label.toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.pricePerKg,
    required this.rating,
    required this.stockKg,
    required this.sellerId,
    required this.sellerName,
    required this.imageUrl,
    required this.description,
    required this.harvestDate,
    required this.isDiscounted,
    required this.discountPrice,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.unit = 'kg',
  });

  factory Product.fromJson(Map<String, dynamic> row) {
    final category = ProductCategory.fromValue(row['category']);
    if (category == null) {
      throw FormatException('Unknown product category: ${row['category']}');
    }

    return Product(
      id: row['id'].toString(),
      name: row['name'] as String,
      category: category,
      subcategory: row['subcategory'] as String,
      pricePerKg: _asDouble(row['price_per_kg']),
      rating: _asDouble(row['rating']),
      stockKg: _asDouble(row['stock_kg']),
      sellerId: row['seller_id'].toString(),
      sellerName: row['seller_name'] as String,
      imageUrl: row['image_url'] as String?,
      description: row['description'] as String? ?? '',
      harvestDate: DateTime.parse(row['harvest_date'].toString()),
      isDiscounted: row['is_discounted'] as bool? ?? false,
      discountPrice: row['discount_price'] == null
          ? null
          : _asDouble(row['discount_price']),
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at'].toString()).toLocal(),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'].toString()).toLocal(),
      unit: row['unit'] as String? ?? 'kg',
    );
  }

  factory Product.fromMap(Map<String, dynamic> row) => Product.fromJson(row);

  final String id;
  final String name;
  final ProductCategory category;
  final String subcategory;
  final double pricePerKg;
  final double rating;
  final double stockKg;
  final String sellerId;
  final String sellerName;
  final String? imageUrl;
  final String description;
  final DateTime harvestDate;
  final bool isDiscounted;
  final double? discountPrice;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String unit;

  double get currentPrice =>
      isDiscounted && discountPrice != null ? discountPrice! : pricePerKg;

  Map<String, dynamic> toJson() => {
    'id': id,
    'seller_id': sellerId,
    'seller_name': sellerName,
    'name': name,
    'category': category.databaseValue,
    'subcategory': subcategory,
    'price_per_kg': pricePerKg,
    'rating': rating,
    'stock_kg': stockKg,
    'image_url': imageUrl,
    'description': description,
    'harvest_date': _dateOnly(harvestDate),
    'is_discounted': isDiscounted,
    'discount_price': discountPrice,
    'is_active': isActive,
    'unit': unit,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    throw FormatException('Expected a numeric product value, got $value.');
  }
}
