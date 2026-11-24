import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'services/supabase_service.dart';
import 'widgets/app_button.dart';
import 'widgets/password_field.dart';

export 'widgets/app_button.dart';

class SharedStartFlow extends StatefulWidget {
  const SharedStartFlow({super.key, required this.supabaseConfigured})
    : _showSplashFirst = false;

  const SharedStartFlow._splash({required this.supabaseConfigured})
    : _showSplashFirst = true;

  final bool supabaseConfigured;
  final bool _showSplashFirst;

  @override
  State<SharedStartFlow> createState() => _SharedStartFlowState();
}

class _SharedStartFlowState extends State<SharedStartFlow> {
  late _StartStage _stage;
  AccountRole? _selectedRole;
  String? _startupError;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _stage = widget._showSplashFirst ? _StartStage.splash : _StartStage.logo;
  }

  Future<void> _continueFromLogo() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    if (!widget.supabaseConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SharedStartFlow._splash(
            supabaseConfigured: widget.supabaseConfigured,
          ),
        ),
      );
      return;
    }

    try {
      final role = await SupabaseService.roleForCurrentUser();
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        role == AccountRole.buyer ? '/home' : '/seller-home',
      );
    } on AuthException catch (error) {
      _showSplashWithError(SupabaseService.errorMessage(error));
    } on PostgrestException catch (error) {
      _showSplashWithError(SupabaseService.errorMessage(error));
    } on Exception catch (error) {
      _showSplashWithError(SupabaseService.errorMessage(error));
    }
  }

  void _showSplashWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isNavigating = false;
      _startupError = message;
      _stage = _StartStage.splash;
    });
  }

  void _openLogin(AccountRole role) {
    setState(() {
      _selectedRole = role;
      _stage = _StartStage.login;
    });
  }

  void _openHome(AccountRole role) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      role == AccountRole.buyer ? '/home' : '/seller-home',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _StartStage.logo:
        return _LogoStartScreen(onContinue: _continueFromLogo);
      case _StartStage.splash:
        return SplashScreen(
          onContinue: () => setState(() => _stage = _StartStage.onboarding),
          startupError: _startupError,
        );
      case _StartStage.onboarding:
        return OnboardingScreen(
          onComplete: () {
            setState(() => _stage = _StartStage.roleSelection);
          },
        );
      case _StartStage.roleSelection:
        return RoleSelectionScreen(
          onContinue: _openLogin,
          onBack: () => setState(() => _stage = _StartStage.onboarding),
        );
      case _StartStage.login:
        return LoginScreen(
          role: _selectedRole!,
          supabaseConfigured: widget.supabaseConfigured,
          onSignedIn: _openHome,
          onChangeRole: () =>
              setState(() => _stage = _StartStage.roleSelection),
        );
    }
  }
}

enum _StartStage { logo, splash, onboarding, roleSelection, login }

class _LogoStartScreen extends StatefulWidget {
  const _LogoStartScreen({required this.onContinue});

  final Future<void> Function() onContinue;

  @override
  State<_LogoStartScreen> createState() => _LogoStartScreenState();
}

class _LogoStartScreenState extends State<_LogoStartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    final curve = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _logoScale = Tween<double>(begin: 0.97, end: 1).animate(curve);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = (MediaQuery.sizeOf(context).width * 0.45)
        .clamp(120.0, 220.0)
        .toDouble();
    return Scaffold(
      backgroundColor: AgriCartColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: 'AgriCart logo, tap to continue',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onContinue,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _logoScale,
                          builder: (context, child) => Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                          child: _StartupLogo(size: logoSize),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupLogo extends StatelessWidget {
  const _StartupLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size * 0.78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: size * 0.04,
                  child: Icon(
                    Icons.shopping_cart,
                    color: AgriCartColors.darkGreen,
                    size: size * 0.68,
                  ),
                ),
                Positioned(
                  top: size * 0.02,
                  left: size * 0.22,
                  child: Icon(
                    Icons.eco,
                    color: AgriCartColors.buttonGreen,
                    size: size * 0.30,
                  ),
                ),
                Positioned(
                  top: size * 0.06,
                  right: size * 0.18,
                  child: Icon(
                    Icons.wb_sunny,
                    color: const Color(0xFFE6B84A),
                    size: size * 0.22,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'AgriCart',
            style: GoogleFonts.poppins(
              color: AgriCartColors.darkGreen,
              fontSize: size * 0.14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onContinue, this.startupError});

  final VoidCallback onContinue;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BrandMark(large: true),
          const SizedBox(height: 18),
          Text(
            'AgriCart',
            style: GoogleFonts.poppins(
              color: AgriCartColors.darkGreen,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fresh from local growers to your table',
            textAlign: TextAlign.center,
            style: TextStyle(color: AgriCartColors.mutedText, fontSize: 15),
          ),
          if (startupError != null) ...[
            const SizedBox(height: 24),
            _InlineError(message: startupError!),
          ],
          const SizedBox(height: 36),
          AppButton(label: 'Get Started', onPressed: onContinue),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;

  static const _slides = [
    _OnboardingSlide(
      title: 'Fresh produce, every day',
      description:
          'Discover fresh vegetables, fruits, rice and more. Bring the goodness of the farm to your table.',
      caption: 'Farm-fresh goodness, all in one cart',
    ),
    _OnboardingSlide(
      title: 'Support our local growers',
      description:
          'Every order helps Filipino sellers and growers. Shop locally grown produce and help communities thrive.',
      caption: 'Grown with care, close to home',
    ),
    _OnboardingSlide(
      title: 'Freshness, your way',
      description:
          'Have your order delivered to your doorstep or pick it up nearby. Choose what works best for you.',
      caption: 'Choose delivery or pickup',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return _CenteredStartLayout(
      topActionAlignment: Alignment.centerRight,
      topAction: TextButton(
        onPressed: widget.onComplete,
        child: const Text('Skip'),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OnboardingArtwork(index: _index, caption: slide.caption),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _index
                      ? AgriCartColors.buttonGreen
                      : AgriCartColors.cardBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Continue',
            onPressed: () {
              if (_index < _slides.length - 1) {
                setState(() => _index++);
              } else {
                widget.onComplete();
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_index + 1} of ${_slides.length}',
            style: const TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredStartLayout extends StatelessWidget {
  const _CenteredStartLayout({
    required this.topActionAlignment,
    required this.topAction,
    required this.child,
  });

  final AlignmentGeometry topActionAlignment;
  final Widget topAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgriCartColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(alignment: topActionAlignment, child: topAction),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.caption,
  });

  final String title;
  final String description;
  final String caption;
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.index, required this.caption});

  final int index;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final artwork = switch (index) {
      0 => Row(
        children: [
          _ArtworkTile(
            icon: Icons.eco_outlined,
            color: const Color(0xFF8FBC75),
          ),
          const SizedBox(width: 8),
          _ArtworkTile(
            icon: Icons.local_florist_outlined,
            color: const Color(0xFFE5B84E),
          ),
        ],
      ),
      1 => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F0DE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.agriculture_outlined,
          color: AgriCartColors.darkGreen,
          size: 88,
        ),
      ),
      _ => Row(
        children: [
          _ChoiceArtworkTile(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery',
            subtitle: 'To your doorstep',
          ),
          const SizedBox(width: 10),
          _ChoiceArtworkTile(
            icon: Icons.storefront_outlined,
            title: 'Pickup',
            subtitle: 'At your convenience',
          ),
        ],
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AgriCartColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          artwork,
          const SizedBox(height: 10),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AgriCartColors.darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AgriCartColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 56, color: color),
      ),
    );
  }
}

class _ChoiceArtworkTile extends StatelessWidget {
  const _ChoiceArtworkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: AgriCartColors.background,
          border: Border.all(color: AgriCartColors.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AgriCartColors.darkGreen, size: 30),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: AgriCartColors.darkGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AgriCartColors.mutedText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
  });

  final ValueChanged<AccountRole> onContinue;
  final VoidCallback onBack;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  AccountRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return _CenteredStartLayout(
      topActionAlignment: Alignment.centerLeft,
      topAction: _BackButton(onPressed: widget.onBack),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _BrandMark(),
          const SizedBox(height: 18),
          Text(
            'Welcome to AgriCart!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your farm-to-table marketplace.\nPlease select how you want to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          RoleCard(
            title: 'Buyer',
            description:
                'Browse fresh produce and buy directly from local sellers.',
            icon: Icons.shopping_basket_outlined,
            features: const [
              'Shop fresh products',
              'Secure payments',
              'Fast delivery',
            ],
            selected: _selectedRole == AccountRole.buyer,
            onTap: () => setState(() => _selectedRole = AccountRole.buyer),
          ),
          const SizedBox(height: 14),
          RoleCard(
            title: 'Seller',
            description:
                'Sell your farm products and grow your business with AgriCart.',
            icon: Icons.storefront_outlined,
            features: const [
              'Create your store',
              'Reach more customers',
              'Grow your income',
            ],
            selected: _selectedRole == AccountRole.seller,
            onTap: () => setState(() => _selectedRole = AccountRole.seller),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Continue',
            onPressed: _selectedRole == null
                ? null
                : () => widget.onContinue(_selectedRole!),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.role,
    required this.supabaseConfigured,
    required this.onSignedIn,
    required this.onChangeRole,
  });

  final AccountRole role;
  final bool supabaseConfigured;
  final ValueChanged<AccountRole> onSignedIn;
  final VoidCallback onChangeRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        context,
        email.isEmpty ? 'Enter your email.' : 'Enter your password.',
      );
      return;
    }
    if (!_isEmailAddress(email)) {
      _showMessage(context, 'Enter a valid email address.');
      return;
    }
    if (!widget.supabaseConfigured) {
      _showMessage(context, _configurationMessage);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final role = await SupabaseService.signIn(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );
      if (mounted) widget.onSignedIn(role);
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        _BackButton(onPressed: widget.onChangeRole),
        const SizedBox(height: 16),
        const _BrandMark(),
        const SizedBox(height: 20),
        Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Sign in as ${widget.role.value == 'buyer' ? 'a Buyer' : 'a Seller'}',
          style: const TextStyle(color: AgriCartColors.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 26),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        PasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Checkbox(
                value: _rememberMe,
                activeColor: AgriCartColors.buttonGreen,
                onChanged: (value) =>
                    setState(() => _rememberMe = value ?? false),
              ),
            ),
            const Expanded(
              child: Text('Remember Me', style: TextStyle(fontSize: 14)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ForgotPasswordScreen(
                    supabaseConfigured: widget.supabaseConfigured,
                  ),
                ),
              ),
              child: const Text('Forgot Password?'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppButton(
          label: 'Continue',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _signIn,
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 14),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RegistrationScreen(
                      role: widget.role,
                      supabaseConfigured: widget.supabaseConfigured,
                    ),
                  ),
                ),
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.role,
    required this.supabaseConfigured,
  });

  final AccountRole role;
  final bool supabaseConfigured;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _farmNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final farmName = _farmNameController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmation.isEmpty) {
      _showMessage(context, 'Please complete all fields.');
      return;
    }
    if (!_isEmailAddress(email)) {
      _showMessage(context, 'Enter a valid email address.');
      return;
    }
    if (widget.role == AccountRole.seller && farmName.isEmpty) {
      _showMessage(context, 'Enter your farm or business name.');
      return;
    }
    if (password.length < 6) {
      _showMessage(context, 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirmation) {
      _showMessage(context, 'Passwords do not match.');
      return;
    }
    if (!widget.supabaseConfigured) {
      _showMessage(context, _configurationMessage);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.register(
        role: widget.role,
        fullName: name,
        email: email,
        password: password,
        farmName: widget.role == AccountRole.seller ? farmName : null,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RegistrationConfirmationScreen(
            role: widget.role,
            email: email,
            farmName: widget.role == AccountRole.seller ? farmName : null,
            needsCode: response.session == null,
            supabaseConfigured: widget.supabaseConfigured,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(context, SupabaseService.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        _BackButton(onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 16),
        const _BrandMark(),
        const SizedBox(height: 18),
        Text(
          'Create your account',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Join AgriCart as a ${widget.role == AccountRole.buyer ? 'Buyer' : 'Seller'}.',
          style: const TextStyle(color: AgriCartColors.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 22),
        AppTextField(
          controller: _nameController,
          label: 'Full name',
          hint: 'Enter your full name',
          textInputAction: TextInputAction.next,
        ),
        if (widget.role == AccountRole.seller) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: _farmNameController,
            label: 'Farm or business name',
            hint: 'Enter your farm or business name',
            textInputAction: TextInputAction.next,
          ),
        ],
        const SizedBox(height: 12),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        PasswordField(
          controller: _passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        PasswordField(
          controller: _confirmPasswordController,
          label: 'Confirm password',
          hint: 'Re-enter your password',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _register(),
        ),
        const SizedBox(height: 22),
        AppButton(
          label: 'Create Account',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _register,
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 14),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RegistrationConfirmationScreen extends StatelessWidget {
  const RegistrationConfirmationScreen({
    super.key,
    required this.role,
    required this.email,
    this.farmName,
    required this.needsCode,
    required this.supabaseConfigured,
  });

  final AccountRole role;
  final String email;
  final String? farmName;
  final bool needsCode;
  final bool supabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        const _BrandMark(),
        const SizedBox(height: 28),
        const _SuccessIcon(),
        const SizedBox(height: 24),
        Text(
          'Registration Confirmation',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          needsCode
              ? 'We sent a confirmation code to $email. Verify it to finish creating your account.'
              : 'Your AgriCart account is ready. You can now sign in as a ${role.value}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AgriCartColors.mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (needsCode)
          AppButton(
            label: 'Enter Verification Code',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OtpScreen(
                  email: email,
                  role: role,
                  farmName: farmName,
                  supabaseConfigured: supabaseConfigured,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        AppButton(
          label: 'Return to Login',
          outlined: needsCode,
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.supabaseConfigured});

  final bool supabaseConfigured;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(context, 'Enter your email.');
      return;
    }
    if (!_isEmailAddress(email)) {
      _showMessage(context, 'Enter a valid email address.');
      return;
    }
    if (!widget.supabaseConfigured) {
      _showMessage(context, _configurationMessage);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await SupabaseService.sendPasswordResetEmail(email);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PasswordResetEmailSentScreen(email: email),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) _showMessage(context, SupabaseService.errorMessage(error));
    } on Exception catch (error) {
      if (mounted) _showMessage(context, SupabaseService.errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        _BackButton(onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 20),
        const Icon(
          Icons.lock_reset_outlined,
          color: AgriCartColors.darkGreen,
          size: 52,
        ),
        const SizedBox(height: 18),
        Text(
          'Forgot Password?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the email linked to your account. We will send you a password reset email.',
          style: TextStyle(
            color: AgriCartColors.mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Send Reset Email',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _sendResetEmail,
        ),
      ],
    );
  }
}

class PasswordResetEmailSentScreen extends StatelessWidget {
  const PasswordResetEmailSentScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        _BackButton(onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 20),
        const _SuccessIcon(),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'If an account exists for $email, Supabase sent a password reset email.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AgriCartColors.mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.role,
    this.farmName,
    required this.supabaseConfigured,
  });

  final String email;
  final AccountRole role;
  final String? farmName;
  final bool supabaseConfigured;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage(context, 'Enter the verification code.');
      return;
    }
    if (!widget.supabaseConfigured) {
      _showMessage(context, _configurationMessage);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await SupabaseService.verifyRegistrationCode(
        email: widget.email,
        code: code,
        role: widget.role,
        farmName: widget.farmName,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RegistrationConfirmationScreen(
            role: widget.role,
            email: widget.email,
            farmName: widget.farmName,
            needsCode: false,
            supabaseConfigured: widget.supabaseConfigured,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) _showMessage(context, SupabaseService.errorMessage(error));
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(context, SupabaseService.errorMessage(error));
    } on Exception catch (error) {
      if (mounted) _showMessage(context, SupabaseService.errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      children: [
        _BackButton(onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 20),
        const Icon(
          Icons.mark_email_read_outlined,
          size: 52,
          color: AgriCartColors.darkGreen,
        ),
        const SizedBox(height: 18),
        Text(
          'Verify your account',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the code sent to ${widget.email}.',
          style: const TextStyle(
            color: AgriCartColors.mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: _codeController,
          label: 'Verification code',
          hint: 'Enter code',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Verify Code',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verify,
        ),
      ],
    );
  }
}

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({
    super.key,
    required this.role,
    required this.onSignOut,
  });

  final AccountRole role;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isBuyer = role == AccountRole.buyer;
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandMark(),
          const SizedBox(height: 32),
          Text(
            isBuyer ? 'Buyer Home' : 'Seller Home',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isBuyer
                ? 'Welcome to AgriCart. Your marketplace is ready.'
                : 'Welcome to AgriCart. Your seller workspace is ready.',
            style: const TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Log out',
            outlined: true,
            onPressed: () async {
              try {
                await onSignOut();
              } on AuthException catch (error) {
                if (context.mounted) {
                  _showMessage(context, SupabaseService.errorMessage(error));
                }
              } on Exception catch (error) {
                if (context.mounted) {
                  _showMessage(context, SupabaseService.errorMessage(error));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.features = const [],
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AgriCartColors.buttonGreen
                  : AgriCartColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AgriCartColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AgriCartColors.darkGreen, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AgriCartColors.mutedText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (features.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final feature in features)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: AgriCartColors.darkGreen,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? AgriCartColors.buttonGreen
                    : AgriCartColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AgriCartColors.mutedText,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgriCartColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 402),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgriCartColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 402,
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 112.0 : 52.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: large ? 8 : 3,
              child: Icon(
                Icons.shopping_cart,
                color: AgriCartColors.darkGreen,
                size: large ? 76 : 38,
              ),
            ),
            Positioned(
              top: large ? 7 : 1,
              left: large ? 25 : 11,
              child: Icon(
                Icons.eco,
                color: AgriCartColors.buttonGreen,
                size: large ? 33 : 17,
              ),
            ),
            Positioned(
              top: large ? 12 : 4,
              right: large ? 20 : 8,
              child: Icon(
                Icons.wb_sunny,
                color: const Color(0xFFE6B84A),
                size: large ? 24 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back),
        color: AgriCartColors.darkGreen,
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFE2F1E2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_outline,
          color: AgriCartColors.darkGreen,
          size: 56,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF8A3030), fontSize: 13),
      ),
    );
  }
}

const _configurationMessage =
    'Supabase is not configured. Add your project URL and anon key to assets/config/supabase.json.';

bool _isEmailAddress(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
