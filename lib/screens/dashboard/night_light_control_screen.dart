import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_error.dart';
import '../../core/theme.dart';
import '../../models/device_model.dart';
import '../../providers/app_providers.dart';
import '../../services/device_service.dart';

class NightLightControlScreen extends ConsumerStatefulWidget {
  final int deviceId;
  const NightLightControlScreen({super.key, required this.deviceId});

  @override
  ConsumerState<NightLightControlScreen> createState() => _NightLightControlScreenState();
}

class _NightLightControlScreenState extends ConsumerState<NightLightControlScreen> {
  bool _localAutoMode = true; // Default to true
  bool _localLed1 = false;
  bool _localLed2 = false;
  bool _localLed3 = false;
  bool _isInit = false;

  void _syncLocalState(DeviceModel device) {
    if (!_isInit && device.nightLightState != null) {
      _localAutoMode = device.nightLightState!.autoMode;
      _localLed1 = device.nightLightState!.led1State;
      _localLed2 = device.nightLightState!.led2State;
      _localLed3 = device.nightLightState!.led3State;
      _isInit = true;

      // Ensure auto mode is turned on by default if it's currently off when entering the screen
      if (!_localAutoMode) {
        _toggleAutoMode(true);
      }
    }
  }

  Future<void> _toggleAutoMode(bool val) async {
    setState(() => _localAutoMode = val);
    try {
      await ref.read(deviceServiceProvider).toggleAutoMode(deviceId: widget.deviceId, autoMode: val);
      await ref.refresh(deviceProvider(widget.deviceId).future);
    } catch (e) {
      setState(() => _localAutoMode = !val);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
    }
  }

  Future<void> _toggleLed(int ledNumber, bool val) async {
    // If auto mode is on, we turn it off first to allow manual control
    if (_localAutoMode) {
      await _toggleAutoMode(false);
    }

    setState(() {
      if (ledNumber == 1) _localLed1 = val;
      if (ledNumber == 2) _localLed2 = val;
      if (ledNumber == 3) _localLed3 = val;
    });

    try {
      await ref.read(deviceServiceProvider).toggleLed(deviceId: widget.deviceId, ledNumber: ledNumber, state: val);
      await ref.refresh(deviceProvider(widget.deviceId).future);
    } catch (e) {
      setState(() {
        if (ledNumber == 1) _localLed1 = !val;
        if (ledNumber == 2) _localLed2 = !val;
        if (ledNumber == 3) _localLed3 = !val;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
    }
  }

  Future<void> _showEditLabelDialog(int ledNumber, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit LED $ledNumber Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter label name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty && newLabel != currentLabel) {
      try {
        await ref.read(deviceServiceProvider).updateLedLabel(
          deviceId: widget.deviceId,
          ledNumber: ledNumber,
          label: newLabel
        );

        // Invalidate both providers to force a fresh fetch
        ref.invalidate(deviceProvider(widget.deviceId));
        ref.invalidate(devicesProvider);

        // Wait for the specific device to be re-fetched
        await ref.read(deviceProvider(widget.deviceId).future);

        // Reset init flag so the local booleans re-sync from the new server data
        if (mounted) {
          setState(() => _isInit = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('LED $ledNumber renamed to "$newLabel"'))
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDevice = ref.watch(deviceProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: asyncDevice.when(
          data: (d) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d.deviceName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Online', style: GoogleFonts.inter(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: asyncDevice.when(
        data: (device) {
          _syncLocalState(device);
          final state = device.nightLightState;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deviceProvider(widget.deviceId));
              ref.invalidate(devicesProvider);
              await ref.read(deviceProvider(widget.deviceId).future);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Auto Mode Card
                  _buildAutoModeCard(),
                  const SizedBox(height: 24),

                  // LED Cards
                  _buildLedCard(1, state?.led1Label ?? 'LED 1', _localLed1),
                  const SizedBox(height: 16),
                  _buildLedCard(2, state?.led2Label ?? 'LED 2', _localLed2),
                  const SizedBox(height: 16),
                  _buildLedCard(3, state?.led3Label ?? 'LED 3', _localLed3),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(message: formatApiErrorMessage(err), onRetry: () => ref.refresh(deviceProvider(widget.deviceId))),
      ),
    );
  }

  Widget _buildAutoModeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto Mode', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('Enable automatic light adjustment based on sensor readings.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
          Switch(
            value: _localAutoMode,
            onChanged: _toggleAutoMode,
            activeTrackColor: const Color(0xFF2563EB),
            activeColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildLedCard(int ledNumber, String label, bool state) {
    Color activeColor;
    IconData icon;
    if (ledNumber == 1) { activeColor = const Color(0xFFF59E0B); icon = Icons.wb_sunny_outlined; }
    else if (ledNumber == 2) { activeColor = const Color(0xFF2563EB); icon = Icons.wb_cloudy_outlined; }
    else { activeColor = const Color(0xFF10B981); icon = Icons.wb_incandescent_outlined; }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: state ? activeColor : AppColors.textHint, size: 28),
              GestureDetector(
                onTap: _localAutoMode ? null : () => _toggleLed(ledNumber, !state),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: state ? activeColor : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.power_settings_new_rounded, color: state ? Colors.white : AppColors.textHint, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state ? AppColors.success : AppColors.textHint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state ? 'ACTIVE - ${_localAutoMode ? "AUTO" : "MANUAL"}' : 'INACTIVE',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: state ? AppColors.textPrimary : AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showEditLabelDialog(ledNumber, label),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
              label: Text('Edit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Could not load device state', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: Text('Retry', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
