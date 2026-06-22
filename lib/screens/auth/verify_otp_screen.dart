import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart' show AppLogo;

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode  = FocusNode();

  bool    _verifying = false;
  bool    _resending = false;
  String? _error;
  String? _success;

  // Countdown timer
  static const _initialSeconds = 60;
  int    _secondsLeft = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _initialSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canResend => _secondsLeft == 0 && !_resending;

  Future<void> _verify() async {
    final code = _pinController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _verifying = true; _error = null; _success = null; });
    try {
      await ref.read(authServiceProvider).verifyOtp(
            email:   widget.email,
            otpCode: code,
          );
      if (mounted) {
        // OTP verified → go to login so user can sign in
        context.go('/login');
      }
    } on DioException catch (e) {
      setState(() =>
          _error = e.response?.data['detail'] ?? 'Verification failed.');
    } catch (_) {
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _resending = true;
      _error     = null;
      _success   = null;
    });
    try {
      await ref.read(authServiceProvider).resendOtp(email: widget.email);
      setState(() => _success = 'A new code has been sent to your email.');
      _pinController.clear();
      _startTimer();
    } on DioException catch (e) {
      setState(() =>
          _error = e.response?.data['detail'] ?? 'Failed to resend OTP.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pinput themes
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
    );

    final filledPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 1.5),
      color: AppColors.primaryLight,
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 1.5),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Back arrow ─────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 22),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/register'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const AppLogo(),
                const SizedBox(height: 24),

                // Title
                Text(
                  'OTP Verification',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "We've sent a 6-digit verification code to your\nregistered device. Please enter it below.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Card ─────────────────────────────────
                Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Error / success banners
                      if (_error != null) ...[
                        _Banner(message: _error!, isError: true),
                        const SizedBox(height: 16),
                      ],
                      if (_success != null) ...[
                        _Banner(message: _success!, isError: false),
                        const SizedBox(height: 16),
                      ],

                      // PIN input
                      Pinput(
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        length: 6,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: filledPinTheme,
                        errorPinTheme: errorPinTheme,
                        pinputAutovalidateMode:
                            PinputAutovalidateMode.onSubmit,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onCompleted: (_) => _verify(),
                      ),
                      const SizedBox(height: 20),

                      // Timer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timerLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _secondsLeft > 0
                                  ? const Color(0xFFEF4444)
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Resend link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive code? ",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _canResend ? _resend : null,
                            child: _resending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  )
                                : Text(
                                    'Resend OTP',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _canResend
                                          ? AppColors.primary
                                          : AppColors.textHint,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _verifying ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.7),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _verifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5),
                                )
                              : Text('Verify',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Banner widget ─────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.inter(
                    fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
