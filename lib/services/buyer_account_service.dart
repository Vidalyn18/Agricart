import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.address,
    required this.isDefault,
  });

  factory SavedAddress.fromMap(Map<String, dynamic> row) => SavedAddress(
    id: row['id'].toString(),
    label: row['label']?.toString() ?? 'Other',
    recipientName: row['recipient_name']?.toString() ?? '',
    phone: row['phone']?.toString() ?? '',
    address: row['address']?.toString() ?? '',
    isDefault: row['is_default'] as bool? ?? false,
  );

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String address;
  final bool isDefault;
}

class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.methodType,
    required this.label,
    required this.accountHint,
    required this.isDefault,
  });

  factory SavedPaymentMethod.fromMap(Map<String, dynamic> row) =>
      SavedPaymentMethod(
        id: row['id'].toString(),
        methodType: row['method_type']?.toString() ?? 'gcash',
        label: row['label']?.toString() ?? '',
        accountHint: row['account_hint']?.toString(),
        isDefault: row['is_default'] as bool? ?? false,
      );

  final String id;
  final String methodType;
  final String label;
  final String? accountHint;
  final bool isDefault;
}

class BuyerAccountService {
  BuyerAccountService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw AuthException('Sign in to manage your account.');
    return id;
  }

  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'You do not have permission to update this information.';
      }
      final details = error.message.toLowerCase();
      if (details.contains('socket') ||
          details.contains('network') ||
          details.contains('connection') ||
          details.contains('timed out')) {
        return 'No connection. Check your internet and try again.';
      }
      return 'We could not save your changes. Please try again.';
    }
    if (error is AuthException) {
      return 'Your session may have expired. Please sign in again.';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  static Future<Profile> fetchProfile() async {
    final userId = _userId;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) throw StateError('Your profile could not be found.');
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<Profile> updateProfile({
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final userId = _userId;
    final row = await _client
        .from('profiles')
        .update({
          'full_name': fullName,
          'phone': phone,
          'address': address,
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<SavedAddress>> fetchAddresses() async {
    final rows = await _client
        .from('saved_addresses')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => SavedAddress.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<SavedAddress> saveAddress({
    String? id,
    required String label,
    required String recipientName,
    required String phone,
    required String address,
    required bool isDefault,
  }) async {
    final userId = _userId;
    final existing = await _client
        .from('saved_addresses')
        .select('id')
        .eq('user_id', userId)
        .limit(1);
    final makeDefault = isDefault || existing.isEmpty;
    if (makeDefault) {
      await _client
          .from('saved_addresses')
          .update({'is_default': false})
          .eq('user_id', userId);
    }
    final values = {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address': address,
      'is_default': makeDefault,
    };
    final row = id == null
        ? await _client
              .from('saved_addresses')
              .insert({...values, 'user_id': userId})
              .select()
              .single()
        : await _client
              .from('saved_addresses')
              .update(values)
              .eq('id', id)
              .eq('user_id', userId)
              .select()
              .single();
    return SavedAddress.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> setDefaultAddress(String id) async {
    final userId = _userId;
    await _client
        .from('saved_addresses')
        .update({'is_default': false})
        .eq('user_id', userId);
    await _client
        .from('saved_addresses')
        .update({'is_default': true})
        .eq('id', id)
        .eq('user_id', userId);
  }

  static Future<void> deleteAddress(String id) async {
    await _client
        .from('saved_addresses')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  static Future<List<SavedPaymentMethod>> fetchPaymentMethods() async {
    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) =>
              SavedPaymentMethod.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<SavedPaymentMethod?> fetchDefaultPaymentMethod() async {
    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('user_id', _userId)
        .eq('is_default', true)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return SavedPaymentMethod.fromMap(Map<String, dynamic>.from(rows.first));
  }

  static Future<SavedPaymentMethod> addPaymentMethod({
    required String methodType,
    required String label,
    required String? accountHint,
    required bool isDefault,
  }) async {
    final userId = _userId;
    if (isDefault) {
      await _client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);
    }
    final row = await _client
        .from('payment_methods')
        .insert({
          'user_id': userId,
          'method_type': methodType,
          'label': label,
          'account_hint': accountHint,
          'is_default': isDefault,
        })
        .select()
        .single();
    return SavedPaymentMethod.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> setDefaultPaymentMethod(String id) async {
    final userId = _userId;
    await _client
        .from('payment_methods')
        .update({'is_default': false})
        .eq('user_id', userId);
    await _client
        .from('payment_methods')
        .update({'is_default': true})
        .eq('id', id)
        .eq('user_id', userId);
  }

  static Future<void> setCashOnDeliveryDefault() async {
    final userId = _userId;
    await _client
        .from('payment_methods')
        .update({'is_default': false})
        .eq('user_id', userId);
    final codRows = await _client
        .from('payment_methods')
        .select('id')
        .eq('user_id', userId)
        .eq('method_type', 'cod')
        .limit(1);
    if (codRows.isEmpty) {
      await _client.from('payment_methods').insert({
        'user_id': userId,
        'method_type': 'cod',
        'label': 'Cash on Delivery',
        'account_hint': null,
        'is_default': true,
      });
    } else {
      await _client
          .from('payment_methods')
          .update({'is_default': true})
          .eq('id', codRows.first['id'])
          .eq('user_id', userId);
    }
  }

  static Future<void> deletePaymentMethod(String id) async {
    await _client
        .from('payment_methods')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
