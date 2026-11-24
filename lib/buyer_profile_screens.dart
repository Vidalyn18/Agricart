import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'models/profile.dart';
import 'services/buyer_account_service.dart';
import 'widgets/app_button.dart';
import 'widgets/password_field.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({
    super.key,
    required this.supabaseConfigured,
    required this.onOpenOrders,
    this.onSignOut,
  });

  final bool supabaseConfigured;
  final VoidCallback onOpenOrders;
  final Future<void> Function()? onSignOut;

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  Profile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (!widget.supabaseConfigured) {
      setState(() {
        _isLoading = false;
        _error = 'Connect Supabase to load your profile.';
      });
      return;
    }
    try {
      final profile = await BuyerAccountService.fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) {
        setState(() => _error = BuyerAccountService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => EditBuyerProfileScreen(profile: profile),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _changePassword() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (password == null || !mounted) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (mounted) _showAccountMessage(context, 'Password updated.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
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
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  size: 44,
                  color: AgriCartColors.darkGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Your profile could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppButton(label: 'Retry', onPressed: _loadProfile),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    final email =
        profile.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AgriCartColors.darkGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
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
                      _initials(profile.fullName),
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
                          profile.fullName,
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
                          label: Text('Buyer'),
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
            const SizedBox(height: 14),
            _ProfileAction(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: _openEditProfile,
            ),
            _ProfileAction(
              icon: Icons.location_on_outlined,
              title: 'Saved Addresses',
              onTap: () => _pushPage(const SavedAddressesScreen()),
            ),
            _ProfileAction(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment Methods',
              onTap: () => _pushPage(const PaymentMethodsScreen()),
            ),
            _ProfileAction(
              icon: Icons.receipt_long_outlined,
              title: 'My Orders',
              onTap: widget.onOpenOrders,
            ),
            _ProfileAction(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: _changePassword,
            ),
            _ProfileAction(
              icon: Icons.help_outline,
              title: 'Help / About',
              onTap: () => _pushPage(const HelpAboutScreen()),
            ),
            _ProfileAction(
              icon: Icons.logout,
              title: 'Log out',
              onTap: _logOut,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  void _pushPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

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
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red.shade700 : AgriCartColors.darkGreen,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive
                ? Colors.red.shade700
                : AgriCartColors.darkGreen,
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

class EditBuyerProfileScreen extends StatefulWidget {
  const EditBuyerProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditBuyerProfileScreen> createState() => _EditBuyerProfileScreenState();
}

class _EditBuyerProfileScreenState extends State<EditBuyerProfileScreen> {
  late final _nameController = TextEditingController(
    text: widget.profile.fullName,
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.profile.address ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final profile = await BuyerAccountService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (mounted) {
        _showAccountMessage(context, 'Profile updated.');
        Navigator.pop(context, profile);
      }
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
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
              _AccountTextField(
                controller: _nameController,
                label: 'Full name',
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Full name is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              _AccountTextField(
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
              _AccountTextField(
                controller: _addressController,
                label: 'Address (optional)',
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

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final addresses = await BuyerAccountService.fetchAddresses();
      if (mounted) setState(() => _addresses = addresses);
    } catch (error) {
      if (mounted) {
        setState(() => _error = BuyerAccountService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editAddress([SavedAddress? address]) async {
    final draft = await showDialog<_AddressDraft>(
      context: context,
      builder: (_) => _AddressDialog(address: address),
    );
    if (draft == null || !mounted) return;
    try {
      await BuyerAccountService.saveAddress(
        id: address?.id,
        label: draft.label,
        recipientName: draft.recipientName,
        phone: draft.phone,
        address: draft.address,
        isDefault: draft.isDefault,
      );
      await _load();
      if (mounted) _showAccountMessage(context, 'Address saved.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  Future<void> _setDefault(SavedAddress address) async {
    try {
      await BuyerAccountService.setDefaultAddress(address.id);
      await _load();
      if (mounted) _showAccountMessage(context, 'Default address updated.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  Future<void> _delete(SavedAddress address) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete address?',
      'This saved address will be removed.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await BuyerAccountService.deleteAddress(address.id);
      await _load();
      if (mounted) _showAccountMessage(context, 'Address deleted.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        actions: [
          IconButton(
            tooltip: 'Add address',
            onPressed: () => _editAddress(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _AccountError(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (_addresses.isEmpty) ...[
                      const _AccountEmpty(
                        icon: Icons.location_on_outlined,
                        title: 'No saved addresses',
                        message: 'Add an address to make checkout quicker.',
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Add address',
                        onPressed: () => _editAddress(),
                      ),
                    ] else ...[
                      for (final address in _addresses)
                        _AddressCard(
                          address: address,
                          onEdit: () => _editAddress(address),
                          onDelete: () => _delete(address),
                          onSetDefault: () => _setDefault(address),
                        ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Saved addresses are only visible to your account.',
                      style: TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final SavedAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AgriCartColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.label,
                    style: const TextStyle(
                      color: AgriCartColors.darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (address.isDefault)
                  const Chip(
                    label: Text('Default'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(address.recipientName, style: const TextStyle(fontSize: 13)),
            if (address.phone.isNotEmpty)
              Text(address.phone, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 5),
            Text(
              address.address,
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Set as default'),
                  ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressDraft {
  const _AddressDraft({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.address,
    required this.isDefault,
  });

  final String label;
  final String recipientName;
  final String phone;
  final String address;
  final bool isDefault;
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.address});

  final SavedAddress? address;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _recipientController = TextEditingController(
    text: widget.address?.recipientName ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.address?.phone ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.address?.address ?? '',
  );
  late String _label = widget.address?.label ?? 'Home';
  late bool _isDefault = widget.address?.isDefault ?? false;

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _AddressDraft(
        label: _label,
        recipientName: _recipientController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.address == null ? 'Add address' : 'Edit address'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _label,
                decoration: const InputDecoration(labelText: 'Label'),
                items: const [
                  DropdownMenuItem(value: 'Home', child: Text('Home')),
                  DropdownMenuItem(value: 'Work', child: Text('Work')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _label = value);
                },
              ),
              const SizedBox(height: 10),
              _AccountTextField(
                controller: _recipientController,
                label: 'Recipient name',
              ),
              const SizedBox(height: 10),
              _AccountTextField(
                controller: _phoneController,
                label: 'Phone',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final phone = (value ?? '').trim();
                  if (phone.isNotEmpty &&
                      !RegExp(r'^\d{7,15}$').hasMatch(phone)) {
                    return 'Enter 7 to 15 digits.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _AccountTextField(
                controller: _addressController,
                label: 'Address',
                maxLines: 3,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Address is required.'
                    : null,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as default',
                  style: TextStyle(fontSize: 13),
                ),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<SavedPaymentMethod> _methods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final methods = await BuyerAccountService.fetchPaymentMethods();
      if (mounted) setState(() => _methods = methods);
    } catch (error) {
      if (mounted) {
        setState(() => _error = BuyerAccountService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _codIsDefault =>
      _methods.any(
        (method) => method.methodType == 'cod' && method.isDefault,
      ) ||
      !_methods.any((method) => method.isDefault);

  Future<void> _add(String methodType) async {
    final draft = await showDialog<_PaymentDraft>(
      context: context,
      builder: (_) => _PaymentDialog(methodType: methodType),
    );
    if (draft == null || !mounted) return;
    try {
      await BuyerAccountService.addPaymentMethod(
        methodType: methodType,
        label: draft.label,
        accountHint: draft.accountHint,
        isDefault: draft.isDefault,
      );
      await _load();
      if (mounted) _showAccountMessage(context, 'Payment method added.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  Future<void> _setDefault(SavedPaymentMethod method) async {
    try {
      await BuyerAccountService.setDefaultPaymentMethod(method.id);
      await _load();
      if (mounted) _showAccountMessage(context, 'Default payment updated.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  Future<void> _setCodDefault() async {
    try {
      await BuyerAccountService.setCashOnDeliveryDefault();
      await _load();
      if (mounted) _showAccountMessage(context, 'Default payment updated.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  Future<void> _delete(SavedPaymentMethod method) async {
    final confirmed = await _confirmDelete(
      context,
      'Delete payment method?',
      'This saved payment method will be removed.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await BuyerAccountService.deletePaymentMethod(method.id);
      await _load();
      if (mounted) _showAccountMessage(context, 'Payment method deleted.');
    } catch (error) {
      if (mounted) {
        _showAccountMessage(
          context,
          BuyerAccountService.errorMessage(error),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedMethods = _methods
        .where((method) => method.methodType != 'cod')
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _AccountError(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _PaymentMethodCard(
                      icon: Icons.payments_outlined,
                      title: 'Cash on Delivery',
                      hint: 'Always available',
                      isDefault: _codIsDefault,
                      onSetDefault: _codIsDefault ? null : _setCodDefault,
                    ),
                    for (final method in savedMethods)
                      _PaymentMethodCard(
                        icon: method.methodType == 'gcash'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card_outlined,
                        title: method.label,
                        hint: [
                          method.methodType == 'gcash' ? 'GCash' : 'Card',
                          if (method.accountHint?.isNotEmpty == true)
                            '•••• ${method.accountHint}',
                        ].join(' · '),
                        isDefault: method.isDefault,
                        onSetDefault: method.isDefault
                            ? null
                            : () => _setDefault(method),
                        onDelete: () => _delete(method),
                      ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Add GCash',
                      outlined: true,
                      onPressed: () => _add('gcash'),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Add Card',
                      outlined: true,
                      onPressed: () => _add('card'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'These are demo payment methods. No real payment is processed.',
                      style: TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.isDefault,
    this.onSetDefault,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool isDefault;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AgriCartColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AgriCartColors.darkGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AgriCartColors.darkGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isDefault)
                  const Chip(
                    label: Text('Default'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (onSetDefault != null)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('Set as default'),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.label,
    required this.accountHint,
    required this.isDefault,
  });

  final String label;
  final String? accountHint;
  final bool isDefault;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.methodType});

  final String methodType;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _accountController = TextEditingController();
  bool _isDefault = false;

  bool get _isGcash => widget.methodType == 'gcash';

  @override
  void dispose() {
    _labelController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final digits = _accountController.text.replaceAll(RegExp(r'\D'), '');
    Navigator.pop(
      context,
      _PaymentDraft(
        label: _labelController.text.trim(),
        accountHint: digits.isEmpty
            ? null
            : digits.substring(digits.length - 4),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isGcash ? 'Add GCash' : 'Add Card';
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AccountTextField(
                controller: _labelController,
                label: _isGcash ? 'Label' : 'Card nickname',
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a label.' : null,
              ),
              const SizedBox(height: 10),
              _AccountTextField(
                controller: _accountController,
                label: _isGcash ? 'Mobile number (optional)' : 'Last 4 digits',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final digits = (value ?? '').trim();
                  if (_isGcash) {
                    if (digits.isNotEmpty &&
                        (digits.length < 7 || digits.length > 15)) {
                      return 'Enter 7 to 15 digits, or leave it blank.';
                    }
                  } else if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
                    return 'Enter exactly 4 digits.';
                  }
                  return null;
                },
              ),
              if (!_isGcash) ...[
                const SizedBox(height: 10),
                const Text(
                  'For this school project, no real payment is processed.',
                  style: TextStyle(
                    color: AgriCartColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as default',
                  style: TextStyle(fontSize: 13),
                ),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

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

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _passwordController.text);
    }
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
        FilledButton(onPressed: _submit, child: const Text('Update')),
      ],
    );
  }
}

class _AccountTextField extends StatelessWidget {
  const _AccountTextField({
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

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AgriCartColors.darkGreen,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _AccountEmpty extends StatelessWidget {
  const _AccountEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AgriCartColors.darkGreen),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmDelete(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _showAccountMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : null,
    ),
  );
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final values = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return values.isEmpty ? 'B' : values;
}
