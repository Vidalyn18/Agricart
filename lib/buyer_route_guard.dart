import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'services/supabase_service.dart';

class BuyerRouteGuard extends StatefulWidget {
  const BuyerRouteGuard({
    super.key,
    required this.supabaseConfigured,
    required this.child,
  });

  final bool supabaseConfigured;
  final Widget child;

  @override
  State<BuyerRouteGuard> createState() => _BuyerRouteGuardState();
}

class _BuyerRouteGuardState extends State<BuyerRouteGuard> {
  late final Future<bool> _access = _checkAccess();

  Future<bool> _checkAccess() async {
    if (!widget.supabaseConfigured) {
      throw StateError('Connect Supabase and sign in as a buyer to continue.');
    }
    final role = await SupabaseService.roleForCurrentUser();
    if (role != AccountRole.buyer) {
      throw AuthException('This screen is available to Buyer accounts only.');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: AgriCartColors.darkGreen,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Buyer access required',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        SupabaseService.errorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, 44),
                        ),
                        child: const Text('Go to start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AgriCartColors.buttonGreen,
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
