import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart'
    show AppLogo, AppFieldLabel, AppErrorBanner;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _usernameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool    _obscurePw      = true;
  bool    _obscureConfirm = true;
  bool    _loading        = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).register(
        username:        _usernameCtrl.text.trim(),
        email:           _emailCtrl.text.trim(),
        password:        _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
      );
      if (mounted) {
        context.push('/verify-otp', extra: _emailCtrl.text.trim());
      }
    } on DioException catch (e) {
      final detail = e.response?.data;
      String msg = 'Registration failed. Please try again.';
      if (detail is String) {
        msg = detail;
      } else if (detail is Map && detail['detail'] != null) {
        final d = detail['detail'];
        if (d is List && d.isNotEmpty) {
          msg = d.map((e) => e['msg'] ?? e.toString()).join('\n');
        } else {
          msg = d.toString();
        }
      }
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo + app name
                      const AppLogo(),
                      const SizedBox(height: 10),
                      Text(
                        'Hajemi Smart',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading
            Text('Create Account',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Join HAJEMI Smart to monitor and\ncontrol your IoT devices.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 28),

            if (_error != null) ...[
              AppErrorBanner(_error!),
              const SizedBox(height: 18),
            ],

            // ── Username ─────────────────────────────────
            const AppFieldLabel('Username'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. smart_user_01',
                prefixIcon:
                    Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Username is required.';
                }
                if (v.trim().length < 3) {
                  return 'Username must be at least 3 characters.';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                  return 'Only letters, numbers and underscores.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Email ────────────────────────────────────
            const AppFieldLabel('Email Address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'name@example.com',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required.';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                    .hasMatch(v.trim())) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password ─────────────────────────────────
            const AppFieldLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePw,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon:
                    const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePw
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePw = !_obscurePw),
                  splashRadius: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required.';
                if (v.length < 8) return 'Minimum 8 characters.';
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return 'Must contain an uppercase letter.';
                }
                if (!RegExp(r'[a-z]').hasMatch(v)) {
                  return 'Must contain a lowercase letter.';
                }
                if (!RegExp(r'[0-9]').hasMatch(v)) {
                  return 'Must contain a number.';
                }
                if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) {
                  return 'Must contain a special character.';
                }
                return null;
              },
            ),
            // Password requirements hint
            const SizedBox(height: 6),
            Text(
              'Min. 8 characters, 1 uppercase, 1 special symbol.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),

            // ── Confirm Password ─────────────────────────
            const AppFieldLabel('Confirm Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm),
                  splashRadius: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (v != _passwordCtrl.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Register button ───────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text('Register',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),

            // ── OR divider ────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHint),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Sign in link ──────────────────────────────
            Center(
              child: Column(
                children: [
                  Text('Already have an account?',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text('Log In',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
