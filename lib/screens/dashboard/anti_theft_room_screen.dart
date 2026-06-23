import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../models/detection_model.dart';
import 'package:intl/intl.dart';

class AntiTheftRoomScreen extends ConsumerWidget {
  final int deviceId;

  const AntiTheftRoomScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetections = ref.watch(roomDetectionsProvider(deviceId));
    final asyncDevice = ref.watch(deviceProvider(deviceId));

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
              'Anti thief logs',
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
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (detections) {
          if (detections.isEmpty) {
            return Center(
              child: Text(
                'No anti-theft logs found.',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            );
          }

          final grouped = _groupDetectionsByDate(detections);
          final deviceName = asyncDevice.value?.deviceName ?? 'Room Sensor';

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final item = grouped[index];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                        child: Text(
                          item.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }

                    return _AntiTheftLogTile(
                      detection: item as DetectionModel,
                      deviceName: deviceName,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Load More History',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(d);
  }
}

class _AntiTheftLogTile extends StatelessWidget {
  final DetectionModel detection;
  final String deviceName;
  const _AntiTheftLogTile({required this.detection, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    final isDetected = detection.detectStatus == 'DETECTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDetected ? const Color(0xFFFFE4E1) : const Color(0xFFE0FFF0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDetected ? Icons.warning_rounded : Icons.check_circle_outline,
              color: isDetected ? const Color(0xFFB91C1C) : const Color(0xFF10B981),
              size: 22,
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
                    color: isDetected ? const Color(0xFFB91C1C) : const Color(0xFF059669),
                  ),
                ),
                Text(
                  deviceName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('HH:mm').format(detection.dateTime),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(detection.dateTime),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
