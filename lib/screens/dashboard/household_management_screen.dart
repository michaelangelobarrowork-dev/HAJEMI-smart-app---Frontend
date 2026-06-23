import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_error.dart';
import '../../core/theme.dart';
import '../../models/household_model.dart';
import '../../services/household_service.dart';
import '../../providers/app_providers.dart';

class HouseholdManagementScreen extends ConsumerStatefulWidget {
  const HouseholdManagementScreen({super.key});

  @override
  ConsumerState<HouseholdManagementScreen> createState() => _HouseholdManagementScreenState();
}

class _HouseholdManagementScreenState extends ConsumerState<HouseholdManagementScreen> {
  bool _isEditingName = false;
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateName(int id) async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    setState(() => _loading = true);
    try {
      await ref.read(householdServiceProvider).updateHouseholdName(id, newName);
      ref.invalidate(householdProvider);
      setState(() => _isEditingName = false);
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _kickMember(int householdId, int userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kick Member'),
        content: Text('Are you sure you want to remove $username from the household?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await ref.read(householdServiceProvider).kickMember(householdId, userId);
        ref.invalidate(householdProvider);
      } on DioException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _leaveHousehold() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Household'),
        content: const Text('Are you sure you want to leave this household?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await ref.read(householdServiceProvider).leaveHousehold();
        // Clear all household-related data
        ref.invalidate(currentUserProvider);
        ref.invalidate(householdProvider);
        ref.invalidate(devicesProvider);
        ref.invalidate(activityLogsProvider);
        if (mounted) context.pop();
      } on DioException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteHousehold(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Household'),
        content: const Text('This will permanently delete the household and remove all members. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await ref.read(householdServiceProvider).deleteHousehold(id);
        // Clear all household-related data
        ref.invalidate(currentUserProvider);
        ref.invalidate(householdProvider);
        ref.invalidate(devicesProvider);
        ref.invalidate(activityLogsProvider);
        if (mounted) context.pop();
      } on DioException catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(formatApiErrorMessage(e))));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Household Management', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: householdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (household) {
          if (household == null) return const Center(child: Text('No household found'));

          final isCreator = userAsync.value?.id == household.creatorId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure your smart home ecosystem and manage member.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // ── Household Name Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HOUSEHOLD NAME', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _isEditingName
                                ? TextField(
                                    controller: _nameCtrl..text = household.name,
                                    autofocus: true,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                  )
                                : Text(household.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          if (isCreator)
                            IconButton(
                              icon: Icon(_isEditingName ? Icons.check_rounded : Icons.edit_outlined, color: AppColors.primary, size: 20),
                              onPressed: () {
                                if (_isEditingName) {
                                  _updateName(household.id);
                                } else {
                                  setState(() => _isEditingName = true);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('JOIN CODE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                household.joinCode,
                                style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1.5),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: household.joinCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Join code copied!'),
                                        duration: Duration(seconds: 1)));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('COPY',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Members Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Household Members (${household.members.length})',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.divider),
                      ...household.members.map((member) => _MemberTile(
                            member: member,
                            isCurrentUserCreator: isCreator,
                            currentUserId: userAsync.value?.id,
                            onKick: () => _kickMember(
                                household.id, member.id, member.username),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Danger Zone ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Danger Zone', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF8B1E1E))),
                              Text('These actions are destructive.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (!isCreator)
                        _DangerButton(
                          label: 'Leave Household',
                          icon: Icons.logout_rounded,
                          onPressed: _loading ? null : _leaveHousehold,
                        )
                      else
                        _DangerButton(
                          label: 'Delete Household',
                          icon: Icons.delete_forever_rounded,
                          onPressed: _loading ? null : () => _deleteHousehold(household.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final HouseholdMember member;
  final bool isCurrentUserCreator;
  final int? currentUserId;
  final VoidCallback onKick;

  const _MemberTile({
    required this.member,
    required this.isCurrentUserCreator,
    this.currentUserId,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMe = currentUserId == member.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.username, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    if (member.isCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('CREATOR', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                Text(member.email, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isCurrentUserCreator && !member.isCreator)
            TextButton.icon(
              onPressed: onKick,
              icon: const Icon(Icons.person_remove_outlined, size: 16, color: AppColors.error),
              label: Text('Kick', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
            )
          else if (isMe)
            const Icon(Icons.check_circle_rounded, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _DangerButton({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC52828),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
