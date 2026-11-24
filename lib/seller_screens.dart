import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'models/order.dart';
import 'models/product.dart';
import 'models/profile.dart';
import 'seller_manage_screens.dart';
import 'services/product_service.dart';
import 'services/seller_service.dart';
import 'services/supabase_service.dart';
import 'utils/format_currency.dart';
import 'widgets/app_button.dart';
import 'widgets/password_field.dart';
import 'widgets/status_chip.dart';

class SellerShell extends StatefulWidget {
  const SellerShell({
    super.key,
    required this.supabaseConfigured,
    this.onSignOut,
  });

  final bool supabaseConfigured;
  final Future<void> Function()? onSignOut;

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String value;
  final IconData icon;
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AgriCartColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AgriCartColors.darkGreen),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerShellState extends State<SellerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const SellerDashboardScreen(),
          const ManageProductsScreen(),
          const SellerOrdersScreen(),
          const SellerSalesScreen(),
          _SellerProfile(
            supabaseConfigured: widget.supabaseConfigured,
            onSignOut: widget.onSignOut,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        height: 80,
        backgroundColor: Colors.white,
        indicatorColor: AgriCartColors.background,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_outlined),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SellerProfile extends StatefulWidget {
  const _SellerProfile({required this.supabaseConfigured, this.onSignOut});

  final bool supabaseConfigured;
  final Future<void> Function()? onSignOut;

  @override
  State<_SellerProfile> createState() => _SellerProfileState();
}

class _SellerProfileState extends State<_SellerProfile> {
  Profile? _profile;
  int _productCount = 0;
  int _orderCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      if (!widget.supabaseConfigured) {
        throw StateError('Connect Supabase to load Seller profile details.');
      }
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException('Sign in as a Seller to view your profile.');
      }
      final row = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        throw StateError('Your Seller profile could not be found.');
      }
      final products = await client
          .from('products')
          .select('id')
          .eq('seller_id', userId);
      final orders = await client
          .from('orders')
          .select('id')
          .eq('seller_id', userId);
      if (!mounted) return;
      setState(() {
        _profile = Profile.fromJson(Map<String, dynamic>.from(row));
        _productCount = products.length;
        _orderCount = orders.length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _sellerProfileError(error));
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => _EditSellerProfileScreen(profile: profile),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
    await _load(showLoading: false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _changePassword() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _SellerPasswordDialog(),
    );
    if (password == null || !mounted) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated.')));
      }
    } catch (error) {
      if (mounted) _showSellerProfileMessage(_sellerProfileError(error));
    }
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.onSignOut == null || !mounted) return;
    try {
      await widget.onSignOut!();
    } catch (error) {
      if (mounted) _showSellerProfileMessage(_sellerProfileError(error));
    }
  }

  void _showSellerProfileMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AgriCartColors.buttonGreen,
                ),
              )
            : _error != null || _profile == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error ?? 'Your Seller profile could not be loaded.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      AppButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                ),
              )
            : _buildProfile(context, _profile!),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, Profile profile) {
    final farmName = profile.farmName?.trim() ?? '';
    final displayName = farmName.isNotEmpty ? farmName : profile.fullName;
    final email =
        profile.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AgriCartColors.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AgriCartColors.background,
                  child: Text(
                    _sellerInitials(displayName),
                    style: const TextStyle(
                      color: AgriCartColors.darkGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? 'Seller' : displayName,
                        style: const TextStyle(
                          color: AgriCartColors.darkGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AgriCartColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Chip(
                        label: Text('Seller'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AgriCartColors.background,
                        side: BorderSide(color: AgriCartColors.cardBorder),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SellerProfileSection(
            title: 'Farm details',
            rows: [
              ('Farm name', farmName),
              ('Pickup address', profile.pickupAddress ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          _SellerProfileSection(
            title: 'Contact',
            rows: [
              ('Full name', profile.fullName),
              ('Phone', profile.phone ?? ''),
              ('Address', profile.address ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Quick stats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AgriCartColors.darkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SellerProfileStat(
                  title: 'Total Products',
                  value: '$_productCount',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SellerProfileStat(
                  title: 'Total Orders',
                  value: '$_orderCount',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Edit Profile', onPressed: _editProfile),
          const SizedBox(height: 8),
          _SellerProfileAction(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: _changePassword,
          ),
          _SellerProfileAction(
            icon: Icons.help_outline,
            title: 'Help / About',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _SellerHelpAboutScreen(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Log out',
            outlined: true,
            onPressed: widget.onSignOut == null ? null : _logOut,
          ),
        ],
      ),
    );
  }
}

class _SellerProfileSection extends StatelessWidget {
  const _SellerProfileSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.trim().isEmpty ? 'Not added yet' : value,
                      style: const TextStyle(fontSize: 13),
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

class _SellerProfileStat extends StatelessWidget {
  const _SellerProfileStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AgriCartColors.darkGreen),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SellerProfileAction extends StatelessWidget {
  const _SellerProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AgriCartColors.cardBorder),
      ),
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(icon, color: AgriCartColors.darkGreen),
        title: Text(
          title,
          style: const TextStyle(
            color: AgriCartColors.darkGreen,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EditSellerProfileScreen extends StatefulWidget {
  const _EditSellerProfileScreen({required this.profile});

  final Profile profile;

  @override
  State<_EditSellerProfileScreen> createState() =>
      _EditSellerProfileScreenState();
}

class _EditSellerProfileScreenState extends State<_EditSellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile.fullName,
  );
  late final _farmController = TextEditingController(
    text: widget.profile.farmName ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.profile.address ?? '',
  );
  late final _pickupController = TextEditingController(
    text: widget.profile.pickupAddress ?? '',
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _farmController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException(
          'Sign in as a Seller to update your profile.',
        );
      }
      final fullName = _nameController.text.trim();
      final farmName = _farmController.text.trim();
      final row = await client
          .from('profiles')
          .update({
            'full_name': fullName,
            'farm_name': farmName,
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'pickup_address': _pickupController.text.trim(),
          })
          .eq('id', userId)
          .select()
          .single();
      await client
          .from('products')
          .update({'seller_name': farmName})
          .eq('seller_id', userId);
      if (mounted) {
        Navigator.pop(
          context,
          Profile.fromJson(Map<String, dynamic>.from(row)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_sellerProfileError(error))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _SellerProfileField(
                controller: _nameController,
                label: 'Full name',
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Full name is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              _SellerProfileField(
                controller: _farmController,
                label: 'Farm name',
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Farm name is required for Sellers.'
                    : null,
              ),
              const SizedBox(height: 14),
              _SellerProfileField(
                controller: _phoneController,
                label: 'Phone (optional)',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final phone = (value ?? '').trim();
                  if (phone.isNotEmpty &&
                      !RegExp(r'^\d{7,15}$').hasMatch(phone)) {
                    return 'Phone must contain 7 to 15 digits.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _SellerProfileField(
                controller: _addressController,
                label: 'Address (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _SellerProfileField(
                controller: _pickupController,
                label: 'Pickup address (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Save Changes',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerProfileField extends StatelessWidget {
  const _SellerProfileField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SellerPasswordDialog extends StatefulWidget {
  const _SellerPasswordDialog();

  @override
  State<_SellerPasswordDialog> createState() => _SellerPasswordDialogState();
}

class _SellerPasswordDialogState extends State<_SellerPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PasswordField(
              controller: _passwordController,
              label: 'New password',
              labelAbove: false,
              validator: (value) => (value ?? '').length < 6
                  ? 'Password must be at least 6 characters.'
                  : null,
            ),
            const SizedBox(height: 10),
            PasswordField(
              controller: _confirmController,
              label: 'Confirm password',
              labelAbove: false,
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _passwordController.text);
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _SellerHelpAboutScreen extends StatelessWidget {
  const _SellerHelpAboutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help / About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.eco_outlined,
              size: 56,
              color: AgriCartColors.darkGreen,
            ),
            const SizedBox(height: 12),
            Text(
              'AgriCart',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AgriCartColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.0+1',
              textAlign: TextAlign.center,
              style: TextStyle(color: AgriCartColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fresh from local sellers',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

String _sellerProfileError(Object error) {
  if (error is StateError) return error.message;
  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'You do not have permission to access these profile details.';
    }
    final details = error.message.toLowerCase();
    if (details.contains('network') ||
        details.contains('socket') ||
        details.contains('connection') ||
        details.contains('timed out') ||
        details.contains('failed to fetch')) {
      return 'No connection. Check your internet and try again.';
    }
    return 'We could not load or save your profile. Please try again.';
  }
  if (error is AuthException) {
    return 'Your session may have expired. Please sign in again.';
  }
  final details = error.toString().toLowerCase();
  if (details.contains('network') ||
      details.contains('socket') ||
      details.contains('connection') ||
      details.contains('timed out')) {
    return 'No connection. Check your internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}

String _sellerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'S' : initials;
}

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, String> _profile = const {};
  List<Product> _products = [];
  List<MarketplaceOrder> _orders = [];

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
      final profileFuture = SupabaseService.fetchSellerProfile();
      final productsFuture = ProductService.fetchSellerProducts();
      final ordersFuture = SellerService.fetchSellerOrders();
      final profile = await profileFuture;
      final products = await productsFuture;
      final orders = await ordersFuture;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _products = products;
        _orders = orders;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = SupabaseService.errorMessage(error));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.errorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _greetingName {
    final farmName = _profile['farm_name']?.trim() ?? '';
    if (farmName.isNotEmpty) return farmName;
    final fullName = _profile['full_name']?.trim() ?? '';
    return fullName.isEmpty ? 'Seller' : fullName;
  }

  List<MarketplaceOrder> get _pendingOrders =>
      _orders.where((order) => order.status == OrderStatus.pending).toList();

  double get _totalSales => _orders
      .where((order) => order.status == OrderStatus.completed)
      .fold(0, (total, order) => total + order.subtotal);

  int get _lowStockCount => _products
      .where((product) => product.stockKg <= kLowStockThreshold)
      .length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AgriCartColors.buttonGreen),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                AppButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Hello, $_greetingName!')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Seller Dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                _SummaryCard(
                  title: 'Total Sales',
                  value: formatPeso(_totalSales),
                  icon: Icons.payments_outlined,
                  onTap: () => Navigator.pushNamed(context, '/seller-sales'),
                ),
                _SummaryCard(
                  title: 'Pending Orders',
                  value: '${_pendingOrders.length}',
                  icon: Icons.pending_actions_outlined,
                  onTap: () => Navigator.pushNamed(context, '/seller-orders'),
                ),
                _SummaryCard(
                  title: 'Total Products',
                  value: '${_products.length}',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => Navigator.pushNamed(context, '/seller-products'),
                ),
                _SummaryCard(
                  title: 'Low Stock',
                  value: '$_lowStockCount',
                  icon: Icons.warning_amber_outlined,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/seller-inventory',
                    arguments: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Newest Pending Orders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_pendingOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No pending orders')),
              )
            else
              ..._pendingOrders
                  .take(3)
                  .map(
                    (order) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        minVerticalPadding: 12,
                        title: Text(
                          order.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          order.buyerName ??
                              order.contactName ??
                              'Buyer ${order.buyerId.substring(0, 8)}',
                        ),
                        trailing: StatusChip(status: order.status),
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
