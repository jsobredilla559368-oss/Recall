import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/services/auth_service.dart';
import '../../profile/widgets/achievement_celebration_dialog.dart';
import '../study_service.dart';
import '../models/session_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/recall_button.dart';

class ResultsScreen extends StatefulWidget {
  final String deckId;
  final int totalCards;
  final int correctCount;
  final String studyMode;

  const ResultsScreen({
    super.key,
    required this.deckId,
    required this.totalCards,
    required this.correctCount,
    this.studyMode = 'due',
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _sessionRecorded = false;
  List<AchievementModel> _newlyUnlocked = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordStudySession();
    });
  }

  Future<void> _recordStudySession() async {
    if (_sessionRecorded) return;
    _sessionRecorded = true;

    try {
      final authService = context.read<AuthService>();
      final studyService = context.read<StudyService>();
      final currentUid = authService.currentUser?.uid ?? '';
      final xpGained = widget.correctCount * 10;

      final session = SessionModel(
        id: '',
        deckId: widget.deckId,
        userId: currentUid,
        completedAt: DateTime.now(),
        totalCards: widget.totalCards,
        correctCount: widget.correctCount,
        xpGained: xpGained,
      );

      final unlocked = await studyService.recordSession(session);
      if (mounted && unlocked.isNotEmpty) {
        setState(() {
          _newlyUnlocked = unlocked;
        });

        // Present milestone celebration after a brief delay for smooth entrance
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) => AchievementCelebrationDialog(
              achievement: unlocked.first,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error auto-recording session in ResultsScreen: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = widget.totalCards == 0 ? 0 : (widget.correctCount / widget.totalCards);
    final int xpGained = widget.correctCount * 10;
    
    String title = 'Good Effort!';
    if (percentage == 1.0) {
      title = 'Perfect Score!';
    } else if (percentage >= 0.8) {
      title = 'Great Job!';
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppColors.auraGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(LucideIcons.award, size: 80, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: widget.studyMode == 'due'
                      ? AppColors.amber.withValues(alpha: 0.15)
                      : AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.studyMode == 'due'
                        ? AppColors.amber.withValues(alpha: 0.3)
                        : AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.studyMode == 'due'
                      ? 'DUE QUEUE REVIEW'
                      : 'CRAM PRACTICE SESSION',
                  style: AppTypography.caption.copyWith(
                    color: widget.studyMode == 'due'
                        ? AppColors.amber
                        : AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(title, style: AppTypography.display),
              const SizedBox(height: 16),
              Text(
                'You completed ${widget.totalCards} cards.',
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 48),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard('Accuracy', '${(percentage * 100).round()}%'),
                  const SizedBox(width: 16),
                  _buildStatCard('XP Gained', '+$xpGained'),
                ],
              ),
              if (_newlyUnlocked.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.award, color: AppColors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked: ${_newlyUnlocked.first.title} (+${_newlyUnlocked.first.xpReward} XP)',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              RecallButton(
                label: 'Return Home',
                icon: LucideIcons.home,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.h1),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}
