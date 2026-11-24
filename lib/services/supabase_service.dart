import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/profile.dart';

enum AccountRole {
  buyer,
  seller;

  String get value => name;

  static AccountRole? fromValue(Object? value) {
    return switch (value) {
      'buyer' => AccountRole.buyer,
      'seller' => AccountRole.seller,
      _ => null,
    };
  }
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<AuthResponse> register({
    required AccountRole role,
    required String fullName,
    required String email,
    required String password,
    String? farmName,
  }) async {
    _requireEmail(email);
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'role': role.value},
    );
    final user = response.user;
    if (user == null) {
      throw AuthException('The account could not be created.');
    }
    if (response.session != null && farmName?.trim().isNotEmpty == true) {
      await updateProfile(farmName: farmName!.trim());
    }
    return response;
  }

  static Future<AccountRole> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    _requireEmail(email);
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw AuthException('Sign in did not return an account.');
    }
    await _setRememberMe(rememberMe);
    return roleForCurrentUser();
  }

  static Future<AuthResponse> verifyRegistrationCode({
    required String email,
    required String code,
    required AccountRole role,
    String? farmName,
  }) async {
    _requireEmail(email);
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
    final user = response.user;
    if (user == null) {
      throw AuthException('The verification code did not return an account.');
    }
    if (AccountRole.fromValue(user.userMetadata?['role']) != role) {
      throw AuthException('The verified account role does not match signup.');
    }
    if (farmName?.trim().isNotEmpty == true) {
      await updateProfile(farmName: farmName!.trim());
    }
    return response;
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    _requireEmail(email);
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Future<AccountRole> roleForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('No signed-in account was found.');
    }
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = AccountRole.fromValue(row?['role']);
    if (role == null) {
      throw AuthException(
        'Your profile does not have a Buyer or Seller role. Please contact support.',
      );
    }
    return role;
  }

  static Future<String> fetchCurrentFirstName() async {
    final fullName = await fetchCurrentFullName();
    final firstName = fullName.trim().split(RegExp(r'\s+')).first;
    return firstName.isEmpty ? 'there' : firstName;
  }

  static Future<String> fetchCurrentFullName() async {
    final user = _client.auth.currentUser;
    if (user == null) return 'there';
    final row = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
    final name =
        row?['full_name']?.toString() ??
        user.userMetadata?['full_name']?.toString() ??
        user.email?.split('@').first ??
        '';
    final fullName = name.trim();
    return fullName.isEmpty ? 'there' : fullName;
  }

  static Future<Map<String, String>> fetchCheckoutProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('Sign in before starting checkout.');
    }

    final row = await _client
        .from('profiles')
        .select('full_name, phone, address')
        .eq('id', user.id)
        .maybeSingle();
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return {
      'full_name':
          row?['full_name']?.toString() ??
          metadata['full_name']?.toString() ??
          '',
      'phone': row?['phone']?.toString() ?? '',
      'street_barangay':
          row?['address']?.toString() ??
          metadata['street_barangay']?.toString() ??
          metadata['delivery_address']?.toString() ??
          '',
      'city': metadata['city']?.toString() ?? '',
      'delivery_notes': metadata['delivery_notes']?.toString() ?? '',
    };
  }

  static Future<Map<String, String>> fetchSellerProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('Sign in before opening Seller tools.');
    }
    final row = await _client
        .from('profiles')
        .select('full_name, farm_name, phone, pickup_address')
        .eq('id', user.id)
        .maybeSingle();
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return {
      'full_name':
          row?['full_name']?.toString() ??
          metadata['full_name']?.toString() ??
          '',
      'farm_name': row?['farm_name']?.toString() ?? '',
      'phone': row?['phone']?.toString() ?? '',
      'pickup_address': row?['pickup_address']?.toString() ?? '',
    };
  }

  static Future<Profile?> fetchProfile([String? profileId]) async {
    final id = profileId ?? _client.auth.currentUser?.id;
    if (id == null) throw AuthException('Sign in to load your profile.');
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : Profile.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<Profile> updateProfile({
    String? fullName,
    String? phone,
    String? address,
    String? farmName,
    String? pickupAddress,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthException('Sign in to update your profile.');
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (farmName != null) updates['farm_name'] = farmName;
    if (pickupAddress != null) updates['pickup_address'] = pickupAddress;
    final row = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<Product>> fetchProducts() async {
    final rows = await _client.from('products').select().eq('is_active', true);
    return rows
        .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<Order> fetchOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) throw StateError('Order not found.');
    return Order.fromJson(Map<String, dynamic>.from(row));
  }

  static Future<List<OrderItem>> fetchOrderItems(String orderId) async {
    final rows = await _client
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return rows
        .map((row) => OrderItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> _setRememberMe(bool rememberMe) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('agricart_remember_me', rememberMe);
  }

  static void _requireEmail(String email) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      throw StateError('Enter a valid email address.');
    }
  }

  static String errorMessage(Object error) {
    if (error is StateError) return error.message;
    if (error is FormatException) {
      return 'The data received from the server was invalid. Please try again.';
    }
    if (error is AuthException) {
      final details = error.message.toLowerCase();
      if (details.contains('already registered') ||
          details.contains('already been registered') ||
          details.contains('user exists')) {
        return 'This email is already registered. Log in or use a different email.';
      }
      if ((error.statusCode == '400' || error.statusCode == '401') &&
          (details.contains('invalid login credentials') ||
              details.contains('invalid_credentials'))) {
        return 'Incorrect email or password.';
      }
      if (details.contains('invalid email') ||
          details.contains('unable to validate email')) {
        return 'Enter a valid email address.';
      }
      if (_looksLikeConnectionError(details)) {
        return 'No connection. Check your internet and try again.';
      }
      if (details.startsWith('{')) {
        return 'Authentication could not be completed. Please try again.';
      }
      return 'Authentication could not be completed. Please try again.';
    }
    if (error is PostgrestException) {
      final details = error.message.toLowerCase();
      if (_looksLikeConnectionError(details)) {
        return 'No connection. Check your internet and try again.';
      }
      if (error.code == 'PGRST205' ||
          error.code == 'PGRST204' ||
          details.startsWith('{')) {
        return 'Profile data could not be loaded. Please try again.';
      }
      if (details.contains('relation') && details.contains('products')) {
        return 'Product data is unavailable. Run supabase/setup.sql in the Supabase SQL Editor.';
      }
      if (details.contains('relation') && details.contains('profiles')) {
        return 'Profile data is unavailable. Run supabase/setup.sql in the Supabase SQL Editor.';
      }
      if (details.contains('full_name') && details.contains('does not exist')) {
        return 'Profile data is unavailable. Run supabase/setup.sql in the Supabase SQL Editor.';
      }
      if (details.contains('column') && details.contains('does not exist')) {
        return 'Product data schema is incomplete. Run the buyer-browse migration in Supabase.';
      }
      if (error.code == '42501') {
        return 'Supabase blocked this request. Check the table’s row-level security policy.';
      }
      return 'The request could not be completed. Please try again.';
    }
    final details = error.toString().toLowerCase();
    if (_looksLikeConnectionError(details)) {
      return 'No connection. Check your internet and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static bool _looksLikeConnectionError(String message) {
    return message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed to fetch') ||
        message.contains('connection') ||
        message.contains('host lookup') ||
        message.contains('timed out');
  }
}
