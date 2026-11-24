import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

class SellerRouteGuard extends StatefulWidget {
  const SellerRouteGuard({
    super.key,
    required this.child,
    required this.supabaseConfigured,
  });

  final Widget child;
  final bool supabaseConfigured;

  @override
  State<SellerRouteGuard> createState() => _SellerRouteGuardState();
}

class _SellerRouteGuardState extends State<SellerRouteGuard> {
  late final Future<AccountRole> _role = SupabaseService.roleForCurrentUser();

  @override
  Widget build(BuildContext context) {
    if (!widget.supabaseConfigured) {
      return const Scaffold(
        body: Center(child: Text('Supabase is not configured.')),
      );
    }
    return FutureBuilder<AccountRole>(
      future: _role,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(SupabaseService.errorMessage(snapshot.error!)),
            ),
          );
        }
        if (snapshot.data != AccountRole.seller) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (_) => false);
          });
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}
