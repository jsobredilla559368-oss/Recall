import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/deck_card.dart';
import '../../../core/widgets/recall_button.dart';
import '../../../core/widgets/streak_badge.dart';
import '../../decks/models/deck_model.dart';
import '../../profile/screens/profile_screen.dart';
import '../../social/screens/explore_screen.dart';
import '../../social/screens/leaderboard_screen.dart';
import '../../study/study_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _totalDueCount = 0;
  int _decksWithDueCount = 0;
  String? _firstDueDeckId;
  final Map<String, int> _dueCountPerDeck = {};
  bool _isLoadingDue = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDailyDueStats();
    });
  }

  Future<void> _loadDailyDueStats() async {
    try {
      final deckService = context.read<DeckService>();
      final studyService = context.read<StudyService>();
      final yourDecks = deckService.yourDecks;

      int totalDue = 0;
      int decksDue = 0;
      String? firstDeck;
      final Map<String, int> dueMap = {};

      for (final deck in yourDecks) {
        final dueCards = await studyService.getDueCardsForDeck(deck.id, deck.isFlashcard);
        final count = dueCards.length;
        dueMap[deck.id] = count;
        if (count > 0) {
          totalDue += count;
          decksDue++;
          firstDeck ??= deck.id;
        }
      }

      if (mounted) {
        setState(() {
          _totalDueCount = totalDue;
          _decksWithDueCount = decksDue;
          _firstDueDeckId = firstDeck;
          _dueCountPerDeck
            ..clear()
            ..addAll(dueMap);
          _isLoadingDue = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDue = false);
    }
  }

  Future<void> _onRefresh() async {
    final deckService = context.read<DeckService>();
    await deckService.refreshDecks();
    if (mounted) {
      await _loadDailyDueStats();
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          const ExploreScreen(),
          const LeaderboardScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () => context.push('/create'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(LucideIcons.plus, color: AppColors.background),
        ),
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.compass), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.trophy), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final deckService = context.watch<DeckService>();
    final yourDecks = deckService.yourDecks;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(), style: AppTypography.body.copyWith(color: AppColors.textMuted)),
                      Consumer<AuthService>(
                        builder: (context, auth, _) {
                          final uid = auth.currentUser?.uid;
                          if (uid == null) return Text('Learner', style: AppTypography.h1);
                          return StreamBuilder<UserModel?>(
                            stream: context.read<UserService>().streamUserProfile(uid),
                            builder: (context, snapshot) {
                              final name = snapshot.data?.displayName ?? auth.currentUser?.displayName;
                              final firstName = (name != null && name.trim().isNotEmpty)
                                  ? name.trim().split(' ').first
                                  : 'Learner';
                              return Text(firstName, style: AppTypography.h1);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final uid = auth.currentUser?.uid;
                      if (uid == null) return const StreakBadge(streak: 0);
                      return StreamBuilder<UserModel?>(
                        stream: context.read<UserService>().streamUserProfile(uid),
                        builder: (context, snapshot) {
                          final streak = snapshot.data?.streakCount ?? 0;
                          return StreakBadge(streak: streak);
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Daily Due Review Hero Card
              _buildDailyReviewHero(yourDecks),
              const SizedBox(height: 32),
              
              Text('Recent Decks', style: AppTypography.h2),
              const SizedBox(height: 16),
              _buildRecentDecks(),
              
              const SizedBox(height: 32),
              Text('Your Decks', style: AppTypography.h2),
              const SizedBox(height: 16),
              _buildYourDecks(yourDecks),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyReviewHero(List<DeckModel> yourDecks) {
    if (_isLoadingDue && yourDecks.isEmpty) {
      return const SizedBox.shrink();
    }

    // Case 1: Brand new user with 0 decks
    if (yourDecks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.sparkles, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Welcome to Recall', style: AppTypography.h2),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Synthesize custom flashcards with Groq AI or build study decks manually to start learning with spaced repetition.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            RecallButton(
              label: 'Create Your First Deck',
              icon: LucideIcons.plus,
              onPressed: () => context.push('/create'),
            ),
          ],
        ),
      );
    }

    // Case 2: Cards are due for review today
    if (_totalDueCount > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.zap, color: AppColors.amber, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'DAILY DUE QUEUE',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.amber,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$_totalDueCount Due',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$_totalDueCount ${_totalDueCount == 1 ? "card needs" : "cards need"} review today',
              style: AppTypography.h1.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'Across $_decksWithDueCount ${_decksWithDueCount == 1 ? "deck" : "decks"} scheduled to protect your retention.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            RecallButton(
              label: 'Start Daily Review',
              icon: LucideIcons.play,
              onPressed: () {
                if (_firstDueDeckId != null) {
                  context.push('/study/$_firstDueDeckId?mode=due').then((_) {
                    if (mounted) _loadDailyDueStats();
                  });
                }
              },
            ),
          ],
        ),
      );
    }

    // Case 3: All caught up! Zero cards due
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Caught Up Today!',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero pending reviews. Cards are safely resting in spaced intervals.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDecks() {
    return Consumer<DeckService>(
      builder: (context, deckService, child) {
        if (deckService.isLoading && deckService.recentDecks.isEmpty) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final decks = deckService.recentDecks;
        if (decks.isEmpty) {
          return Text('No recent decks.', style: AppTypography.caption);
        }
        
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: decks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final deck = decks[index];
              return SizedBox(
                width: 240,
                child: DeckCard(
                  title: deck.title,
                  subtitle: deck.tag,
                  totalCards: deck.totalCards,
                  tag: deck.isFlashcard ? 'Flashcards' : 'MCQ',
                  isFlashcard: deck.isFlashcard,
                  dueCount: _dueCountPerDeck[deck.id],
                  onTap: () => context.push('/deck/${deck.id}').then((_) {
                    if (mounted) _loadDailyDueStats();
                  }),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildYourDecks(List<DeckModel> decks) {
    if (decks.isEmpty) {
      return Text("You haven't created any decks yet.", style: AppTypography.caption);
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: decks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final deck = decks[index];
        return DeckCard(
          title: deck.title,
          subtitle: deck.description,
          totalCards: deck.totalCards,
          tag: deck.isFlashcard ? 'Flashcards' : 'MCQ',
          isFlashcard: deck.isFlashcard,
          dueCount: _dueCountPerDeck[deck.id],
          onTap: () => context.push('/deck/${deck.id}').then((_) {
            if (mounted) _loadDailyDueStats();
          }),
        );
      },
    );
  }
}
