import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/deck_card.dart';
import '../widgets/achievement_badge_widget.dart';
import '../widgets/achievement_detail_sheet.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/profile_stat_card.dart';
import '../widgets/theme_picker_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserStudyStats? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      final stats = await context.read<UserService>().fetchUserStats(uid);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatJoinDate(DateTime? date) {
    if (date == null) return 'joined 2026';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'joined ${months[date.month - 1]} ${date.year}';
  }

  void _showEditNameDialog(String currentName, String uid) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Display Name', style: AppTypography.h2),
        content: TextField(
          controller: controller,
          style: AppTypography.body,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: AppTypography.caption,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await context.read<UserService>().updateDisplayName(uid, newName);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Display name updated!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAllAchievements(List<AchievementModel> achievements) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('All Milestones', style: AppTypography.h1),
            const SizedBox(height: 6),
            Text(
              'Earn milestone badges and XP bonuses as you master your decks.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: achievements.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = achievements[index];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => AchievementDetailSheet(achievement: a),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: a.isUnlocked
                              ? a.primaryColor.withValues(alpha: 0.4)
                              : AppColors.textMuted.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: a.isUnlocked
                                  ? a.primaryColor.withValues(alpha: 0.15)
                                  : AppColors.surface,
                              border: Border.all(
                                color: a.isUnlocked
                                    ? a.primaryColor
                                    : AppColors.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              a.icon,
                              size: 22,
                              color: a.isUnlocked ? a.primaryColor : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.description,
                                  style: AppTypography.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (a.isUnlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: a.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Earned',
                                style: AppTypography.caption.copyWith(
                                  color: a.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              '${(a.progress * 100).toInt()}%',
                              style: AppTypography.caption,
                            ),
                        ],
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

  void _showSettingsSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Settings & Account', style: AppTypography.h1),
            const SizedBox(height: 20),

            // Profile picture tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.camera, color: AppColors.accent),
              title: Text('Edit Profile Picture', style: AppTypography.bodyMedium),
              subtitle: Text(
                user.photoUrl == null ? 'Monogram Initial' : 'Custom Photo / Avatar',
                style: AppTypography.caption,
              ),
              trailing: const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.textMuted),
              onTap: () {
                Navigator.pop(context);
                _openAvatarPicker(user);
              },
            ),
            const Divider(color: Colors.white10),

            // Profile info tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.user, color: AppColors.accent),
              title: Text('Edit Name', style: AppTypography.bodyMedium),
              subtitle: Text(user.displayName, style: AppTypography.caption),
              trailing: const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.textMuted),
              onTap: () {
                Navigator.pop(context);
                _showEditNameDialog(user.displayName, user.uid);
              },
            ),
            const Divider(color: Colors.white10),

            // Theme & Gradient Colors tile
            ListenableBuilder(
              listenable: ThemeService.instance,
              builder: (context, _) {
                final themeService = ThemeService.instance;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(LucideIcons.palette, color: AppColors.accent),
                  title: Text('Theme & Gradient Colors',
                      style: AppTypography.bodyMedium),
                  subtitle: Text(
                    themeService.selectedPreset != null
                        ? themeService.selectedPreset!.name
                        : 'Custom Hue (${themeService.hue.round()}°)',
                    style: AppTypography.caption,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: themeService.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: themeService.primaryColor
                                  .withValues(alpha: 0.4),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.chevronRight,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openThemePicker();
                  },
                );
              },
            ),
            const Divider(color: Colors.white10),

            // AI Info Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.cpu, color: AppColors.accent),
              title: Text('AI Inference Engine', style: AppTypography.bodyMedium),
              subtitle:
                  const Text('Groq Llama-3.3 (Ultra-fast)', style: TextStyle(color: AppColors.textMuted)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Online',
                    style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const Divider(color: Colors.white10),

            // Spaced Repetition Tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.refreshCw, color: AppColors.accent),
              title: Text('Algorithm', style: AppTypography.bodyMedium),
              subtitle: const Text('SuperMemo SM-2 Adaptive Spaced Repetition',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: const Text('Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmSignOut();
                },
              ),
            ),
            const SizedBox(height: 12),

            // Delete Account Button (App Store Guideline 5.1.1 compliant)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.textMuted),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: AppTypography.h2),
        content: Text('Are you sure you want to sign out of Recall?',
            style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final auth = context.read<AuthService>();
              await auth.signOut();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(UserModel user) {
    final confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDeleteWordEntered = confirmController.text.trim() == 'DELETE';

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 24),
                const SizedBox(width: 8),
                Text('Delete Account', style: AppTypography.h2),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action is permanent and cannot be undone.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• All your private decks and cards will be erased.\n'
                    '• Your personal spaced repetition progress and study logs will be permanently deleted.\n'
                    '• Any public decks you shared will remain in the community catalog and be anonymized under "Anonymous Scholar".',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type "DELETE" to confirm:',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    enabled: !isDeleting,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDeleteWordEntered
                              ? AppColors.error
                              : AppColors.textMuted.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (!isDeleteWordEntered || isDeleting)
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        await _executeAccountDeletion(user, dialogCtx);
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Permanently Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeAccountDeletion(
    UserModel user,
    BuildContext dialogCtx,
  ) async {
    final userService = context.read<UserService>();
    final authService = context.read<AuthService>();
    final storageService = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Cascade delete Firestore data and Storage assets
      await userService.deleteAccountCascade(user.uid, storageService: storageService);

      // 2. Delete Auth user credentials
      try {
        await authService.deleteCurrentUser();
      } on FirebaseAuthException catch (authErr) {
        if (authErr.code == 'requires-recent-login') {
          // Token is stale. Prompt reauthentication challenge
          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
          if (mounted) {
            _showReauthForDeletionDialog(user);
          }
          return;
        }
        rethrow;
      }

      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your account and personal data have been completely deleted.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to complete account deletion: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReauthForDeletionDialog(UserModel user) {
    final passwordController = TextEditingController();
    bool isReauthing = false;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isGoogleUser = currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (reauthCtx) => StatefulBuilder(
        builder: (ctx, setReauthState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Security Verification', style: AppTypography.h2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Because this action is sensitive, please confirm your credentials before we finalize account deletion.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 16),
                if (!isGoogleUser) ...[
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    enabled: !isReauthing,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: AppTypography.caption,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'You signed in with Google (${user.email ?? "Google Account"}). Tap below to verify.',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isReauthing ? null : () => Navigator.pop(reauthCtx),
                child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: isReauthing
                    ? null
                    : () async {
                        setReauthState(() => isReauthing = true);
                        try {
                          final authService = context.read<AuthService>();
                          if (isGoogleUser) {
                            await authService.reauthenticateWithGoogle();
                          } else {
                            final pw = passwordController.text;
                            if (pw.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter your password.'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              setReauthState(() => isReauthing = false);
                              return;
                            }
                            await authService.reauthenticateWithPassword(pw);
                          }

                          // Now proceed with final deletion
                          await authService.deleteCurrentUser();

                          if (reauthCtx.mounted) Navigator.pop(reauthCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account permanently deleted.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            context.go('/login');
                          }
                        } catch (e) {
                          setReauthState(() => isReauthing = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Verification failed: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                child: isReauthing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isGoogleUser ? 'Verify with Google' : 'Verify & Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAvatarPicker(UserModel profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AvatarPickerSheet(
        uid: profile.uid,
        displayName: profile.displayName,
        currentPhotoUrl: profile.photoUrl,
      ),
    );
  }

  void _openThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ThemePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
          stream: context.read<UserService>().streamUserProfile(uid),
          builder: (context, snapshot) {
            final profile = snapshot.data ??
                UserModel(
                  uid: uid,
                  displayName: user?.displayName ?? 'Learner',
                  email: user?.email,
                  photoUrl: user?.photoURL,
                );

            final currentEmail = profile.email ?? user?.email ?? '';
            final handle = currentEmail.isNotEmpty
                ? '@${currentEmail.split('@').first}'
                : '@learner';

            final leaderboard = context.watch<UserService>().leaderboard;
            final userRank = leaderboard.indexWhere((u) => u.uid == uid) + 1;

            final achievements = AchievementModel.evaluateAll(
              streakDays: profile.streakCount,
              cardsStudied: _stats?.totalCardsStudied ?? profile.totalCardsStudied,
              userRank: userRank,
              accuracy: _stats?.overallAccuracy ?? 0.0,
              unlockedIds: profile.unlockedAchievements,
            );

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                final userService = context.read<UserService>();
                await _loadStats();
                await userService.refreshLeaderboard();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROFILE',
                          style: AppTypography.caption.copyWith(
                            letterSpacing: 1.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.settings,
                              color: AppColors.textMuted, size: 20),
                          tooltip: 'Settings',
                          onPressed: () => _showSettingsSheet(profile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // HERO IDENTITY SECTION
                    Center(
                      child: Column(
                        children: [
                          // Glowing Avatar with Interactive Camera Edit Badge
                          AppAvatar(
                            photoUrl: profile.photoUrl,
                            displayName: profile.displayName,
                            radius: 44,
                            borderWidth: 2.5,
                            showEditBadge: true,
                            onEdit: () => _openAvatarPicker(profile),
                          ),
                          const SizedBox(height: 14),

                          // Display Name with Edit Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                profile.displayName,
                                style: AppTypography.h1.copyWith(fontSize: 24),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showEditNameDialog(
                                    profile.displayName, profile.uid),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: const Icon(
                                    LucideIcons.pencil,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Handle & Join Date
                          Text(
                            '$handle · ${_formatJoinDate(profile.createdAt)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Streak Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.amber.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.flame,
                                    size: 16, color: AppColors.amber),
                                const SizedBox(width: 6),
                                Text(
                                  '${profile.streakCount} ${profile.streakCount == 1 ? "Day" : "Days"} Streak',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 3-COLUMN STATS GRID
                    Row(
                      children: [
                        Expanded(
                          child: ProfileStatCard(
                            value: _isLoadingStats
                                ? '...'
                                : '${_stats?.totalDecks ?? 0}',
                            label: 'Decks',
                            accentColor: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProfileStatCard(
                            value: _isLoadingStats
                                ? '...'
                                : _formatNumber(_stats?.totalCardsStudied ??
                                    profile.totalCardsStudied),
                            label: 'Cards Studied',
                            accentColor: const Color(0xFF38BDF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProfileStatCard(
                            value: _isLoadingStats
                                ? '...'
                                : '${((_stats?.overallAccuracy ?? 0.0) * 100).round()}%',
                            label: 'Accuracy',
                            accentColor: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ACHIEVEMENTS / MILESTONES SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACHIEVEMENTS',
                          style: AppTypography.caption.copyWith(
                            letterSpacing: 1.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: () => _showAllAchievements(achievements),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            child: Text(
                              'Show All',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Achievements Horizontal Row (Vector Badges, No Emojis)
                    SizedBox(
                      height: 104,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: achievements.length,
                        itemBuilder: (context, index) {
                          return AchievementBadgeWidget(
                            achievement: achievements[index],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // USER'S RECENT DECKS
                    Text(
                      'MY DECKS',
                      style: AppTypography.caption.copyWith(
                        letterSpacing: 1.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Consumer<DeckService>(
                      builder: (context, deckService, child) {
                        final myDecks = deckService.yourDecks;

                        if (myDecks.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.textMuted.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(LucideIcons.layers,
                                    color: AppColors.textMuted, size: 32),
                                const SizedBox(height: 10),
                                Text('No decks created yet',
                                    style: AppTypography.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Generate your first flashcard deck with AI!',
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.plus, size: 16),
                                  label: const Text('Create Deck',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () => context.push('/create'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: myDecks.take(4).map((deck) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: DeckCard(
                                title: deck.title,
                                subtitle: deck.tag,
                                totalCards: deck.totalCards,
                                tag: deck.tag,
                                isFlashcard: deck.isFlashcard,
                                onTap: () => context.push('/deck/${deck.id}'),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
