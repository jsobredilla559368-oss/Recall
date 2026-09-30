import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/app_avatar.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  String _formatScore(int score) {
    return score.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUid = authService.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: Consumer<UserService>(
          builder: (context, userService, child) {
            if (userService.isLoading && userService.leaderboard.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            final topUsers = userService.leaderboard;

            // Resolve whether the current user is in the top 10
            UserModel? currentUserInTop;
            int currentUserRank = 0;

            if (currentUid != null && topUsers.isNotEmpty) {
              final index = topUsers.indexWhere((u) => u.uid == currentUid);
              if (index != -1) {
                currentUserInTop = topUsers[index];
                currentUserRank = index + 1;
              }
            }

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                await userService.refreshLeaderboard();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEADERBOARD',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Top Scholars', style: AppTypography.display),
                          const SizedBox(height: 20),

                          // Current User Ranking Card ("Your Ranking")
                          if (currentUid != null) ...[
                            Text(
                              'Your Ranking',
                              style: AppTypography.h2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 12),
                            if (currentUserInTop != null)
                              _buildCurrentUserCard(currentUserInTop, currentUserRank)
                            else
                              StreamBuilder<UserModel?>(
                                stream: userService.streamUserProfile(currentUid),
                                builder: (context, snapshot) {
                                  final profile = snapshot.data;
                                  if (profile == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return _buildCurrentUserCard(profile, 0);
                                },
                              ),
                          ],

                          const SizedBox(height: 28),
                          Text(
                            'Global Standings',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildLeaderboardTile(topUsers[index], index + 1);
                        },
                        childCount: topUsers.length,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32.0)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentUserCard(UserModel user, int rank) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + Rank Tag
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                radius: 24,
                borderWidth: 1.5,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rank > 0 ? '#$rank' : '10+',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // User Info (You, Display Name, Score)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You',
                  style: AppTypography.h2.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.displayName,
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${_formatScore(user.score)} XP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Contained Streak Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.flame, color: AppColors.amber, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '${user.streakCount} ${user.streakCount == 1 ? 'Day' : 'Days'}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Study Streak',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.amber.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(UserModel user, int rank) {
    final isFirst = rank == 1;
    final isSecond = rank == 2;
    final isThird = rank == 3;

    Color tileColor = AppColors.surface;
    Color borderColor = AppColors.textMuted.withValues(alpha: 0.08);
    Color rankColor = AppColors.textMuted;
    Color scoreColor = AppColors.textPrimary;

    if (isFirst) {
      tileColor = AppColors.amber.withValues(alpha: 0.12);
      borderColor = AppColors.amber.withValues(alpha: 0.35);
      rankColor = AppColors.amber;
      scoreColor = AppColors.amber;
    } else if (isSecond) {
      tileColor = const Color(0xFF94A3B8).withValues(alpha: 0.08);
      borderColor = const Color(0xFF94A3B8).withValues(alpha: 0.25);
      rankColor = const Color(0xFF94A3B8);
      scoreColor = const Color(0xFFCBD5E1);
    } else if (isThird) {
      tileColor = const Color(0xFFCD7F32).withValues(alpha: 0.08);
      borderColor = const Color(0xFFCD7F32).withValues(alpha: 0.25);
      rankColor = const Color(0xFFCD7F32);
      scoreColor = const Color(0xFFE2A05B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Rank Badge / Icon
          SizedBox(
            width: 36,
            child: isFirst
                ? const Icon(LucideIcons.crown, color: AppColors.amber, size: 20)
                : Text(
                    '#$rank',
                    style: AppTypography.bodyMedium.copyWith(
                      color: rankColor,
                      fontWeight: (isSecond || isThird)
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
          ),

          // User Avatar
          AppAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 17,
            borderWidth: 1.2,
            borderColor: isFirst ? AppColors.amber : null,
            glowColor: isFirst ? AppColors.amber.withValues(alpha: 0.3) : Colors.transparent,
          ),
          const SizedBox(width: 12),

          // User Display Name
          Expanded(
            child: Text(
              user.displayName,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: (isFirst || isSecond || isThird)
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Score
          Text(
            '${_formatScore(user.score)} XP',
            style: AppTypography.bodyMedium.copyWith(
              color: scoreColor,
              fontWeight: (isFirst || isSecond || isThird)
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
