import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../models/detection_model.dart';
import 'package:intl/intl.dart';

class GateSecurityScreen extends ConsumerWidget {
  final int deviceId;

  const GateSecurityScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetections = ref.watch(gateDetectionsProvider(deviceId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0D2E4A),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Text(
              'Security Logs',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D2E4A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: asyncDetections.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              formatApiErrorMessage(err),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (detections) {
          if (detections.isEmpty) {
            return Center(
              child: Text(
                'No security logs found.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          final grouped = _groupDetectionsByDate(detections);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: grouped.length + 1,
            itemBuilder: (context, index) {
              if (index == grouped.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1E40AF)),
                    label: Text(
                      'View Older Events',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                );
              }

              final item = grouped[index];
              if (item is String) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        item.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                );
              }

              return _DetectionTile(detection: item as DetectionModel);
            },
          );
        },
      ),
    );
  }

  List<dynamic> _groupDetectionsByDate(List<DetectionModel> detections) {
    final List<dynamic> items = [];
    String? currentGroup;

    final sorted = List<DetectionModel>.from(detections)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (final d in sorted) {
      final dateStr = _getDateHeader(d.dateTime);
      if (dateStr != currentGroup) {
        items.add(dateStr);
        currentGroup = dateStr;
      }
      items.add(d);
    }
    return items;
  }

  String _getDateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(d.year, d.month, d.day);

    final format = DateFormat('MMM d, yyyy');
    if (date == today) return 'Today, ${format.format(d)}';
    if (date == yesterday) return 'Yesterday, ${format.format(d)}';
    return format.format(d);
  }
}

class _DetectionTile extends StatelessWidget {
  final DetectionModel detection;
  const _DetectionTile({required this.detection});

  @override
  Widget build(BuildContext context) {
    final isDetected = detection.detectStatus == 'DETECTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDetected ? const Color(0xFFFFE4E1) : const Color(0xFFE0FFF0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDetected ? Icons.directions_run : Icons.check_circle_outline,
              color: isDetected ? const Color(0xFFE57373) : const Color(0xFF66BB6A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDetected ? 'Movement Detected' : 'No Motion',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gate Sensor • ${DateFormat('HH:mm:ss').format(detection.dateTime)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatRelativeTime(detection.dateTime),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return DateFormat('HH:mm').format(d);
  }
}
