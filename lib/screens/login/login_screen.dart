import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Login screen — Megit's premium auth experience.
/// Hero brand panel + glassmorphic form card with animated gradients.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSignup = false;
  bool _showPassword = false;
  bool _submitting = false;
  String _error = '';
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameC.text.trim();
    final email = _emailC.text.trim();
    final password = _passwordC.text;

    if (_isSignup && name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final auth = ref.read(authProvider.notifier);
      if (_isSignup) {
        await auth.signupWithEmail(email, password, name);
      } else {
        await auth.loginWithEmail(email, password);
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .replaceAll('Firebase: ', '')
            .replaceAll(RegExp(r'\(auth/.*\)'), '')
            .trim());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final secondary = AppColors.computeSecondary(accent);

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated halo backgrounds ──
          Positioned(
            top: -160,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.haloGradient(accent),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -140,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.haloGradient(secondary),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Brand mark ──
                      _BrandHeader(accent: accent),
                      const SizedBox(height: 32),

                      // ── Auth card ──
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.06),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ── Segmented toggle ──
                            _AuthToggle(
                              isSignup: _isSignup,
                              accent: accent,
                              onToggle: (v) => setState(() {
                                _isSignup = v;
                                _error = '';
                              }),
                            ),
                            const SizedBox(height: 22),

                            Text(
                              _isSignup ? 'Create your account' : 'Welcome back',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSignup
                                  ? 'Start your premium music journey'
                                  : 'Sign in to continue your sound experience',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),

                            if (_isSignup)
                              _PremiumInput(
                                controller: _nameC,
                                hint: 'Your name',
                                icon: LucideIcons.user,
                              ),

                            _PremiumInput(
                              controller: _emailC,
                              hint: 'Email address',
                              icon: LucideIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            _PremiumInput(
                              controller: _passwordC,
                              hint: 'Password',
                              icon: LucideIcons.lock,
                              obscure: !_showPassword,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _showPassword = !_showPassword),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14),
                                  child: Icon(
                                    _showPassword
                                        ? LucideIcons.eye_off
                                        : LucideIcons.eye,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),

                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.danger.withValues(alpha: 0.30),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.circle_alert,
                                        size: 14, color: AppColors.danger),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),

                            // ── Primary CTA ──
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: AppTheme.accentGradient(accent),
                                  boxShadow: AppTheme.accentGlow(accent),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _submitting ? null : _handleSubmit,
                                    child: Center(
                                      child: _submitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.black,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _isSignup
                                                      ? 'Create Account'
                                                      : 'Sign In',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(LucideIcons.arrow_right,
                                                    size: 18, color: Colors.black),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.glassBorder)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR', style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
                                ),
                                Expanded(child: Divider(color: AppColors.glassBorder)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Google Sign-In CTA ──
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _submitting ? null : () async {
                                  setState(() {
                                    _submitting = true;
                                    _error = '';
                                  });
                                  try {
                                    await ref.read(authProvider.notifier).loginWithGoogle();
                                    if (mounted) context.go('/');
                                  } catch (e) {
                                    if (mounted) setState(() => _error = e.toString());
                                  } finally {
                                    if (mounted) setState(() => _submitting = false);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: const BorderSide(color: AppColors.glassBorder),
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(LucideIcons.globe, size: 20, color: AppColors.textPrimary),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isSignup ? 'Sign up with Google' : 'Sign in with Google',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                      Text(
                        'By continuing, you agree to our Terms & Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final Color accent;
  const _BrandHeader({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Brand mark
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: AppTheme.accentGradient(accent),
            boxShadow: AppTheme.accentGlow(accent, opacity: 0.45),
          ),
          child: const Icon(
            LucideIcons.audio_waveform,
            size: 36,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.accentGradient(accent).createShader(bounds),
          child: const Text(
            'MEGIT',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Premium sound. Effortless flow.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AuthToggle extends StatelessWidget {
  final bool isSignup;
  final Color accent;
  final ValueChanged<bool> onToggle;

  const _AuthToggle({
    required this.isSignup,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: isSignup ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: AppTheme.accentGradient(accent),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSignup ? AppColors.textSecondary : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSignup ? Colors.black : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;

  const _PremiumInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(icon, size: 18, color: AppColors.textTertiary),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (suffix != null) suffix!,
          ],
        ),
      ),
    );
  }
}
