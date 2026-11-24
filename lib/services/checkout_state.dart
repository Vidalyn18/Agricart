import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import 'buyer_account_service.dart';
import 'cart_service.dart';
import 'supabase_service.dart';

const double kDeliveryFeePerSeller = 50;

class CheckoutState extends ChangeNotifier {
  CheckoutState._() : checkoutId = _newUuid();

  static final CheckoutState instance = CheckoutState._();

  String checkoutId;
  FulfillmentType fulfillmentType = FulfillmentType.delivery;
  PaymentMethod paymentMethod = PaymentMethod.cod;
  String streetBarangay = '';
  String city = '';
  String deliveryNotes = '';
  String contactName = '';
  String contactPhone = '';
  bool isLoadingProfile = false;
  String? profileError;
  bool _profileLoaded = false;
  int _profileLoadGeneration = 0;

  double get subtotal => CartService.instance.subtotal;
  int get sellerCount =>
      CartService.instance.items.map((item) => item.sellerId).toSet().length;
  double get deliveryFeePerSeller =>
      fulfillmentType == FulfillmentType.delivery ? kDeliveryFeePerSeller : 0;
  double get deliveryFee => sellerCount * deliveryFeePerSeller;
  double get total => subtotal + deliveryFee;

  String get deliveryAddress {
    final parts = <String>[
      streetBarangay.trim(),
      city.trim(),
      if (deliveryNotes.trim().isNotEmpty) 'Notes: ${deliveryNotes.trim()}',
    ]..removeWhere((part) => part.isEmpty);
    return parts.join(', ');
  }

  Future<void> loadProfileDefaults() async {
    if (_profileLoaded || isLoadingProfile) return;
    final generation = _profileLoadGeneration;
    isLoadingProfile = true;
    profileError = null;
    notifyListeners();
    try {
      final profile = await SupabaseService.fetchCheckoutProfile();
      if (generation != _profileLoadGeneration) {
        return;
      }
      if (contactName.isEmpty) contactName = profile['full_name'] ?? '';
      if (contactPhone.isEmpty) contactPhone = profile['phone'] ?? '';
      if (streetBarangay.isEmpty) {
        streetBarangay = profile['street_barangay'] ?? '';
      }
      if (city.isEmpty) city = profile['city'] ?? '';
      if (deliveryNotes.isEmpty) {
        deliveryNotes = profile['delivery_notes'] ?? '';
      }
      _profileLoaded = true;
    } catch (error) {
      if (generation != _profileLoadGeneration) return;
      profileError = BuyerAccountService.errorMessage(error);
      _profileLoaded = true;
    } finally {
      if (generation == _profileLoadGeneration) {
        isLoadingProfile = false;
        notifyListeners();
      }
    }
  }

  void setFulfillmentType(FulfillmentType value) {
    if (fulfillmentType == value) return;
    fulfillmentType = value;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod value) {
    if (paymentMethod == value) return;
    paymentMethod = value;
    notifyListeners();
  }

  void setStreetBarangay(String value) {
    streetBarangay = value;
    notifyListeners();
  }

  void setCity(String value) {
    city = value;
    notifyListeners();
  }

  void setDeliveryNotes(String value) {
    deliveryNotes = value;
    notifyListeners();
  }

  void setContactName(String value) {
    contactName = value;
    notifyListeners();
  }

  void setContactPhone(String value) {
    contactPhone = value;
    notifyListeners();
  }

  void clearAfterOrder() {
    _profileLoadGeneration++;
    checkoutId = _newUuid();
    fulfillmentType = FulfillmentType.delivery;
    paymentMethod = PaymentMethod.cod;
    streetBarangay = '';
    city = '';
    deliveryNotes = '';
    contactName = '';
    contactPhone = '';
    isLoadingProfile = false;
    profileError = null;
    _profileLoaded = false;
    notifyListeners();
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
