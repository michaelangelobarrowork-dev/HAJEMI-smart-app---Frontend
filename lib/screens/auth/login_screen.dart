import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_error.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();

  bool    _obscure  = true;
  bool    _remember = false;
  bool    _loading  = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).login(
        identifier: _identifierCtrl.text.trim(),
        password:   _passwordCtrl.text,
        rememberMe: _remember,
      );

      // Register FCM token after successful login
      await ref.read(notificationServiceProvider).registerToken();

      if (mounted) context.go('/dashboard');
    } on DioException catch (e) {
      setState(() => _error = formatApiErrorMessage(e));
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
            // ── Scrollable body ───────────────────────────
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
            Text('Welcome Back',
                style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Access your HAJEMI smart device\nmanagement dashboard.',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 28),

            // Error banner
            if (_error != null) ...[
              AppErrorBanner(_error!),
              const SizedBox(height: 18),
            ],

            // Username or Email
            const AppFieldLabel('Username or Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _identifierCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'name@company.com',
                prefixIcon:
                    Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter your username or email.'
                  : null,
            ),
            const SizedBox(height: 18),

            // Password row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppFieldLabel('Password'),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon:
                    const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
                  splashRadius: 20,
                ),
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter your password.'
                  : null,
            ),
            const SizedBox(height: 16),

            // Remember this device
            GestureDetector(
              onTap: () => setState(() => _remember = !_remember),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (v) =>
                          setState(() => _remember = v ?? false),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Remember this device',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Login to Dashboard',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          const SizedBox(width: 8),
                          const Icon(Icons.login_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 22),

            // Create account link — centered
            Center(
              child: Column(
                children: [
                  Text(
                    "Don't have an account?",
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => context.push('/register'),
                    child: Text(
                      'Create an account',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
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

// ── Shared widgets ─────────────────────────────────────────────────────────────

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF0D2E4A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
    );
  }
}

class AppFieldLabel extends StatelessWidget {
  final String text;
  const AppFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
      );
}

class AppErrorBanner extends StatelessWidget {
  final String message;
  const AppErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.error)),
            ),
          ],
        ),
      );
}


