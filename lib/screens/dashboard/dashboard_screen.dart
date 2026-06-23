import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_error.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/device_model.dart';
import '../../models/user_model.dart';
import '../../models/log_model.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/user_service.dart';
import '../../services/household_service.dart';
import '../../services/dio_client.dart';
import '../../providers/app_providers.dart';

final dashboardTabProvider = StateProvider<int>((ref) => 0);

class ProfileSummary {
  final String username;
  final String email;
  final int deviceCount;

  const ProfileSummary({
    required this.username,
    required this.email,
    required this.deviceCount,
  });

  factory ProfileSummary.fromToken(String? token, int deviceCount) {
    final fallback = ProfileSummary(
      username: 'User',
      email: 'No email available',
      deviceCount: deviceCount,
    );

    if (token == null || token.split('.').length < 2) {
      return fallback;
    }

    try {
      final payload = token.split('.')[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return ProfileSummary(
        username: (json['username'] ?? json['sub'] ?? 'User') as String,
        email: (json['email'] ?? '') as String,
        deviceCount: deviceCount,
      );
    } catch (_) {
      return fallback;
    }
  }
}

final profileProvider = FutureProvider.autoDispose<ProfileSummary>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final token = await storage.read(key: StorageKeys.accessToken);
  final devices = await ref.watch(deviceServiceProvider).getDevices();
  return ProfileSummary.fromToken(token, devices.length);
});

// ── Root scaffold with bottom nav ─────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(dashboardTabProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentTab,
        children: const [
          _DevicesTab(),
          _ActivityTab(),
          _AlertsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: currentTab,
        onTap: (i) {
          ref.read(dashboardTabProvider.notifier).state = i;
        },
      ),
    );
  }
}

// ── Devices Tab ───────────────────────────────────────────────────────────────

class _DevicesTab extends ConsumerStatefulWidget {
  const _DevicesTab();

  @override
  ConsumerState<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends ConsumerState<_DevicesTab> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncDevices = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(devicesProvider);
          ref.invalidate(householdProvider);
          ref.invalidate(activityLogsProvider);
        },
        child: asyncDevices.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => _ErrorState(
            message: formatApiErrorMessage(err),
            onRetry: () {
              ref.invalidate(devicesProvider);
              ref.invalidate(currentUserProvider);
            },
          ),
          data: (devices) {
            final user = ref.watch(currentUserProvider).value;
            final filteredDevices = devices.where((d) =>
                d.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                d.deviceType.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

            if (_isSearching && _searchQuery.isNotEmpty) {
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                itemCount: filteredDevices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _DeviceCard(device: filteredDevices[i]),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingSection(username: user?.username ?? 'User'),
                  const SizedBox(height: 24),
                  const _ActionButtons(),
                  const SizedBox(height: 32),
                  const _HouseholdCard(),
                  const SizedBox(height: 32),
                  _HomeDevicesSection(devices: filteredDevices),
                  if (filteredDevices.isEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _isSearching ? 'No devices match your search.' : 'No devices registered yet.',
                        style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const _RecentActivitySection(),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search devices...',
            border: InputBorder.none,
            hintStyle: GoogleFonts.inter(color: AppColors.textHint),
          ),
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () {
              if (_searchController.text.isEmpty) {
                setState(() {
                  _isSearching = false;
                });
              } else {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      );
    }

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        children: [
          // Logo thumbnail
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2E4A),
              borderRadius: BorderRadius.circular(9),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'HAJEMI ',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              TextSpan(
                text: 'smart',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary),
              ),
            ]),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 26),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              color: AppColors.textSecondary, size: 26),
          onPressed: () => ref.read(dashboardTabProvider.notifier).state = 2,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }
}

// ── Activity Tab ──────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(activityLogsProvider);
    final asyncDevices = ref.watch(devicesProvider);
    final filters = ref.watch(logFiltersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Activity Logs',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D2E4A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.read(dashboardTabProvider.notifier).state = 2,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'System telemetry and user interaction history',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVICE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                asyncDevices.when(
                  data: (devices) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: filters.deviceId,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Devices')),
                          ...devices.map((d) => DropdownMenuItem(
                            value: d.id.toString(),
                            child: Text(d.deviceName),
                          )),
                        ],
                        onChanged: (val) {
                          ref.read(logFiltersProvider.notifier).update((s) => s.copyWith(deviceId: val));
                        },
                      ),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading devices'),
                ),
                const SizedBox(height: 16),
                Text(
                  'DATE RANGE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: filters.dateRange,
                    );
                    if (picked != null) {
                      ref.read(logFiltersProvider.notifier).update((s) => s.copyWith(dateRange: picked));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          filters.dateRange == null
                              ? 'Select Date Range'
                              : '${_formatDateShort(filters.dateRange!.start)} - ${_formatDateShort(filters.dateRange!.end)}',
                          style: GoogleFonts.inter(
                            color: filters.dateRange == null ? AppColors.textHint : AppColors.textPrimary,
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Actions',
                        isSelected: filters.actionType == 'all',
                        onTap: () => ref.read(logFiltersProvider.notifier).update((s) => s.copyWith(actionType: 'all')),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Alerts',
                        isSelected: filters.actionType == 'critical_alert',
                        onTap: () => ref.read(logFiltersProvider.notifier).update((s) => s.copyWith(actionType: 'critical_alert')),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Security',
                        isSelected: filters.actionType == 'security',
                        onTap: () => ref.read(logFiltersProvider.notifier).update((s) => s.copyWith(actionType: 'security')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(activityLogsProvider),
              child: asyncLogs.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 64, color: AppColors.textHint),
                          const SizedBox(height: 16),
                          Text('No logs found.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  final grouped = _groupLogsByDate(logs);

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final item = grouped[index];
                      if (item is String) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 12),
                          child: Text(
                            item.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHint,
                              letterSpacing: 1.0,
                            ),
                          ),
                        );
                      }
                      return _ActivityLogTile(log: item as LogModel);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(DateTime d) {
    return '${d.month}/${d.day}/${d.year}';
  }

  List<dynamic> _groupLogsByDate(List<LogModel> logs) {
    final List<dynamic> items = [];
    String? currentGroup;

    final sorted = List<LogModel>.from(logs)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final log in sorted) {
      final dateStr = _getDateHeader(log.createdAt);
      if (dateStr != currentGroup) {
        items.add(dateStr);
        currentGroup = dateStr;
      }
      items.add(log);
    }
    return items;
  }

  String _getDateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDate = DateTime(d.year, d.month, d.day);

    if (logDate == today) return 'Today';
    if (logDate == yesterday) return 'Yesterday';
    return '${d.day} ${_getMonthName(d.month)} ${d.year}';
  }

  String _getMonthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ── Alerts Tab ──────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Alerts',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.notifications_none_rounded,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No alerts.',
                style: GoogleFonts.inter(
                    fontSize: 16, color: AppColors.textSecondary)),
          ]),
        ),
      );
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
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
              'HAJEMI smart',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: asyncUser.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.refresh(currentUserProvider),
        ),
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              // Account Details Card
              _AccountDetailsCard(
                username: user.username,
                email: user.email,
                onEdit: () => _showEditProfileDialog(context, ref, user),
              ),
              const SizedBox(height: 20),

              // Change Password Card
              _ProfileOptionCard(
                icon: Icons.refresh_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordDialog(context, ref),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),

              // Notification Preferences Card
              _ProfileOptionCard(
                icon: Icons.notifications_none_rounded,
                iconColor: const Color(0xFF92400E),
                iconBg: const Color(0xFFFFF7ED),
                title: 'Notification Preferences',
                subtitle: 'Configure alerts for IoT device triggers',
                onTap: () {},
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: Colors.white,
                  activeTrackColor: const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 32),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (context.mounted) context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: Text(
                    'Logout',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Version Info
              Text(
                'HAJEMI smart Version 2.4.1 (Stable Build 440)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  final String username;
  final String email;
  final VoidCallback onEdit;

  const _AccountDetailsCard({
    required this.username,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, color: Color(0xFF1E40AF), size: 28),
              const SizedBox(width: 12),
              Text(
                'Account Details',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AccountField(label: 'USERNAME', value: username),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1),
          const SizedBox(height: 16),
          _AccountField(label: 'EMAIL ADDRESS', value: email),
        ],
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  final String label;
  final String value;

  const _AccountField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _ProfileOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  const _ProfileOptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'Activity',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.notifications_outlined,
                label: 'Alerts',
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon,
                  size: 22,
                  color: active ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Widgets ─────────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final String username;
  const _GreetingSection({required this.username});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = 'Good evening';
    if (hour < 12) greeting = 'Good morning';
    else if (hour < 17) greeting = 'Good afternoon';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $username',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's what's happening in your home today.",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ActionButton(
          label: 'Register Device',
          icon: Icons.bolt_rounded,
          color: AppColors.primary,
          textColor: Colors.white,
          onTap: () => context.push('/register-device'),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'Create Household',
          icon: Icons.home_rounded,
          color: const Color(0xFF53F0A4),
          textColor: Colors.white,
          onTap: () => _showCreateHouseholdDialog(context, ref),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'Join Household',
          icon: Icons.group_add_rounded,
          color: Colors.white,
          textColor: AppColors.primary,
          borderColor: AppColors.primary,
          onTap: () => _showJoinHouseholdDialog(context, ref),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HouseholdCard extends ConsumerWidget {
  const _HouseholdCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHousehold = ref.watch(householdProvider);

    return asyncHousehold.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text('no household', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ),
      ),
      data: (household) {
        if (household == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text('no household', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F0FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.home_rounded, color: AppColors.primary, size: 28),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F0FB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Primary Home',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                household.name,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    household.joinCode,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, thickness: 1),
              const SizedBox(height: 16),
              Text(
                '${household.members.length} members active',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/household-management'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Household',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeDevicesSection extends StatelessWidget {
  final List<DeviceModel> devices;
  const _HomeDevicesSection({required this.devices});

  @override
  Widget build(BuildContext context) {
    final nightLight = devices.where((d) => d.deviceType == 'Auto Night Light').firstOrNull;
    final security = devices.where((d) => d.deviceType == 'Home Security').firstOrNull;
    final thiefSecurity = devices.where((d) => d.deviceType == 'Anti-thief Security').firstOrNull;

    if (nightLight == null && security == null && thiefSecurity == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Home Devices',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        if (nightLight != null) ...[
          _DeviceTypeCard(
            device: nightLight,
            icon: Icons.wb_incandescent_rounded,
            iconBg: const Color(0xFF53F0A4),
            subtitle: 'Home Device',
          ),
          const SizedBox(height: 16),
        ],
        if (security != null) ...[
          _DeviceTypeCard(
            device: security,
            icon: Icons.security_rounded,
            iconBg: const Color(0xFFF1F5F9),
            iconColor: AppColors.textSecondary,
            subtitle: 'Hallway Setup',
          ),
          const SizedBox(height: 16),
        ],
        if (thiefSecurity != null) ...[
          _DeviceTypeCard(
            device: thiefSecurity,
            icon: Icons.shield_rounded,
            iconBg: const Color(0xFF53F0A4),
            subtitle: 'Active Protection',
            statusLabel: 'ON',
          ),
        ],
      ],
    );
  }
}

class _DeviceTypeCard extends StatelessWidget {
  final DeviceModel device;
  final IconData icon;
  final Color iconBg;
  final Color? iconColor;
  final String subtitle;
  final String? statusLabel;

  const _DeviceTypeCard({
    required this.device,
    required this.icon,
    required this.iconBg,
    this.iconColor,
    required this.subtitle,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? Colors.white, size: 26),
              ),
              _OnlineBadge(online: online, activeLabel: statusLabel != null ? 'Active' : 'Online'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            device.deviceName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel ?? (online ? 'Online' : 'OFFLINE'),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: online ? AppColors.textPrimary : AppColors.textHint,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: online ? () {
                    if (device.deviceType == 'Auto Night Light') {
                      context.push('/device-control/${device.id}');
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: online ? AppColors.primary : AppColors.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

class _OnlineBadge extends StatelessWidget {
  final bool online;
  final String activeLabel;
  const _OnlineBadge({required this.online, required this.activeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (online ? AppColors.success : AppColors.textHint).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? AppColors.success : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? activeLabel : 'Offline',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: online ? AppColors.success : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLogs = ref.watch(activityLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => ref.read(dashboardTabProvider.notifier).state = 1,
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        asyncLogs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (logs) {
            final recent = logs.take(3).toList();
            if (recent.isEmpty) {
              return Center(
                child: Text(
                  'No recent activity',
                  style: GoogleFonts.inter(color: AppColors.textHint),
                ),
              );
            }

            return Column(
              children: recent.map((log) => _ActivityLogTile(log: log)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActivityLogTile extends StatelessWidget {
  final LogModel log;
  const _ActivityLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final isAlert = log.actionType == 'critical_alert';
    final isSecurity = log.actionType == 'security' || log.actionType.contains('lock');

    Color accentColor = const Color(0xFF2563EB); // Default blue
    IconData icon = Icons.info_outline_rounded;
    String category = 'ACTIVITY';
    Color categoryBg = const Color(0xFFF1F5F9);
    Color categoryText = const Color(0xFF64748B);

    if (isAlert) {
      accentColor = const Color(0xFFEF4444); // Red
      icon = Icons.warning_amber_rounded;
      category = 'CRITICAL';
      categoryBg = const Color(0xFFFEF2F2);
      categoryText = const Color(0xFFEF4444);
    } else if (isSecurity) {
      accentColor = const Color(0xFF059669); // Green
      icon = Icons.shield_outlined;
      category = 'SECURITY';
      categoryBg = const Color(0xFFECFDF5);
      categoryText = const Color(0xFF059669);
    } else if (log.actionType.contains('automation')) {
      accentColor = const Color(0xFF7C3AED); // Purple
      icon = Icons.smart_toy_outlined;
      category = 'AUTOMATION';
      categoryBg = const Color(0xFFF5F3FF);
      categoryText = const Color(0xFF7C3AED);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAlert ? const Border(left: BorderSide(color: Color(0xFFEF4444), width: 4)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isAlert && !log.performerDisplay.contains('System'))
                   CircleAvatar(
                    radius: 18,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    child: Text(
                      log.performerDisplay.isNotEmpty ? log.performerDisplay.substring(0, 1).toUpperCase() : '?',
                      style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.performerDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatTime(log.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: categoryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              log.message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (isAlert) ...[
               const SizedBox(height: 12),
               Row(
                 children: [
                   TextButton(
                     onPressed: () {},
                     style: TextButton.styleFrom(
                       padding: EdgeInsets.zero,
                       minimumSize: Size.zero,
                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                     ),
                     child: Text('View Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                   ),
                   const SizedBox(width: 16),
                   Text('Acknowledge', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                 ],
               ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  log.triggeredBy == 'System' ? Icons.access_time_rounded : Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  log.deviceName ?? log.triggeredBy,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final amPm = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }
}

// ── General Widgets ───────────────────────────────────────────────────────────

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
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Error occurred',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 20),
              label: Text('Retry',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;

    return InkWell(
      onTap: () {
        if (device.deviceType == 'Auto Night Light') {
          context.push('/device-control/${device.id}');
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: online
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.router_rounded,
                size: 28,
                color: online ? AppColors.primary : AppColors.textHint,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.deviceType,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: online
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? AppColors.success : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: online ? AppColors.success : AppColors.textHint,
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

class _DeviceList extends StatelessWidget {
  final List<DeviceModel> devices;
  const _DeviceList({required this.devices});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DeviceCard(device: devices[i]),
    );
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

void _showCreateHouseholdDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _CreateHouseholdDialog(ref: ref),
  );
}

void _showJoinHouseholdDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _JoinHouseholdDialog(ref: ref),
  );
}

class _CreateHouseholdDialog extends StatefulWidget {
  final WidgetRef ref;
  const _CreateHouseholdDialog({required this.ref});

  @override
  State<_CreateHouseholdDialog> createState() => _CreateHouseholdDialogState();
}

class _CreateHouseholdDialogState extends State<_CreateHouseholdDialog> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.ref.read(householdServiceProvider).createHousehold(name);
      widget.ref.invalidate(currentUserProvider);
      widget.ref.invalidate(householdProvider);
      widget.ref.invalidate(devicesProvider);
      widget.ref.invalidate(activityLogsProvider);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = formatApiErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Failed to create household.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Create Household',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Give your home a name to get started.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Villa Lumi',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Create', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _JoinHouseholdDialog extends StatefulWidget {
  final WidgetRef ref;
  const _JoinHouseholdDialog({required this.ref});

  @override
  State<_JoinHouseholdDialog> createState() => _JoinHouseholdDialogState();
}

class _JoinHouseholdDialogState extends State<_JoinHouseholdDialog> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.ref.read(householdServiceProvider).joinHousehold(code);
      widget.ref.invalidate(currentUserProvider);
      widget.ref.invalidate(householdProvider);
      widget.ref.invalidate(devicesProvider);
      widget.ref.invalidate(activityLogsProvider);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = formatApiErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Failed to join household.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Join Household',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the join code shared by the household creator.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(
              _error!,
              style: GoogleFonts.inter(color: AppColors.error, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _codeCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. LUMI-123',
              prefixIcon: Icon(Icons.group_add_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Join', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserModel user) {
  showDialog(
    context: context,
    builder: (context) => _EditProfileDialog(ref: ref, user: user),
  );
}

void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _ChangePasswordDialog(ref: ref),
  );
}

class _EditProfileDialog extends StatefulWidget {
  final WidgetRef ref;
  final UserModel user;
  const _EditProfileDialog({required this.ref, required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _emailCtrl = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (username.isEmpty || email.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userService = widget.ref.read(userServiceProvider);
      if (username != widget.user.username) {
        await userService.updateUsername(username);
      }
      if (email != widget.user.email) {
        await userService.updateEmail(email);
      }
      widget.ref.invalidate(currentUserProvider);
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = formatApiErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Failed to update profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Edit Profile',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ChangePasswordDialog({required this.ref});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPwd = _currentPwdCtrl.text;
    final newPwd = _newPwdCtrl.text;
    if (currentPwd.isEmpty || newPwd.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.ref.read(userServiceProvider).updatePassword(currentPwd, newPwd);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } on DioException catch (e) {
      setState(() => _error = formatApiErrorMessage(e));
    } catch (e) {
      setState(() => _error = 'Failed to change password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Change Password',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _currentPwdCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPwdCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Update', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
