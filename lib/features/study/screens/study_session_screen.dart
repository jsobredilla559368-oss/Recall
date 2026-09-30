import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/utils/spaced_repetition.dart';
import '../../../core/widgets/recall_button.dart';
import '../study_service.dart';
import '../models/card_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/flash_card.dart';
import '../../../core/widgets/mcq_option.dart';

class StudySessionScreen extends StatefulWidget {
  final String deckId;
  final String studyMode;
  final int? timerDuration;

  const StudySessionScreen({
    super.key,
    required this.deckId,
    this.studyMode = 'due',
    this.timerDuration,
  });

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  late String _activeMode;
  late PageController _pageController;
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOptionIndex;
  List<CardModel>? _cards;
  List<CardModel>? _allDeckCards;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  Timer? _cardTimer;
  int _timeRemaining = 0;
  bool _forceReveal = false;
  bool _isTimedOut = false;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.studyMode;
    _pageController = PageController();
    _loadSession();
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _cardTimer?.cancel();
    if (widget.timerDuration == null || _cards == null || _cards!.isEmpty) return;

    setState(() {
      _timeRemaining = widget.timerDuration!;
      _forceReveal = false;
      _isTimedOut = false;
    });

    _cardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_isProcessing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _forceReveal = true;
      _isTimedOut = true;
      _isProcessing = true;
    });
    
    // Penalize the user
    final currentCard = _cards![_currentIndex];
    context.read<StudyService>().recordAnswer(currentCard, false);

    // Wait 2 seconds for them to see the answer, then move on
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentIndex < _cards!.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        });
      } else {
        context.replace(
          '/study/${widget.deckId}/results',
          extra: {
            'totalCards': _cards!.length,
            'correctCount': _correctCount,
            'studyMode': _activeMode,
          },
        );
      }
    });
  }

  Future<void> _loadSession() async {
    try {
      final deckService = context.read<DeckService>();
      final deck = await deckService.getDeckById(widget.deckId);
      
      if (deck == null) {
        setState(() {
          _error = 'Deck not found';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      final studyService = context.read<StudyService>();
      final cards = await studyService.getCardsForDeck(widget.deckId, deck.isFlashcard);
      _allDeckCards = cards;

      final List<CardModel> sessionCards;
      if (_activeMode == 'due') {
        sessionCards = SpacedRepetition.filterDueCards(cards);
      } else {
        sessionCards = List<CardModel>.from(cards);
      }
      
      setState(() {
        _cards = sessionCards;
        _isLoading = false;
      });
      if (sessionCards.isNotEmpty) {
        _startTimer();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _switchToCramMode() {
    if (_allDeckCards == null || _allDeckCards!.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _activeMode = 'all';
      _cards = List<CardModel>.from(_allDeckCards!);
      _currentIndex = 0;
      _correctCount = 0;
      _selectedOptionIndex = null;
      _isProcessing = false;
    });
    _startTimer();
  }

  void _handleAnswer(bool passed) {
    if (_cards == null || _isProcessing) return;
    _isProcessing = true;
    _cardTimer?.cancel();
    
    final currentCard = _cards![_currentIndex];
    context.read<StudyService>().recordAnswer(currentCard, passed);
    
    if (passed) {
      HapticFeedback.mediumImpact();
      _correctCount++;
    } else {
      HapticFeedback.heavyImpact();
    }

    if (_currentIndex < _cards!.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      });
    } else {
      // Session Complete
      context.replace(
        '/study/${widget.deckId}/results',
        extra: {
          'totalCards': _cards!.length,
          'correctCount': _correctCount,
          'studyMode': _activeMode,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_error != null || _cards == null || _cards!.isEmpty) {
      if (_activeMode == 'due' && _allDeckCards != null && _allDeckCards!.isNotEmpty) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(LucideIcons.checkCircle2, size: 56, color: AppColors.success),
                  ),
                  const SizedBox(height: 24),
                  Text('All Caught Up!', style: AppTypography.display),
                  const SizedBox(height: 12),
                  Text(
                    'There are no cards due for review in this deck today. You can cram all ${_allDeckCards!.length} cards if you want extra practice.',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  RecallButton(
                    label: 'Cram All Cards (${_allDeckCards!.length})',
                    icon: LucideIcons.repeat,
                    onPressed: _switchToCramMode,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Back to Deck', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.layers, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(_error ?? 'No cards available in this deck.', style: AppTypography.body),
                const SizedBox(height: 24),
                RecallButton(
                  label: 'Back to Deck',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = (_currentIndex + 1) / _cards!.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _activeMode == 'due'
                        ? AppColors.amber.withValues(alpha: 0.15)
                        : AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _activeMode == 'due'
                          ? AppColors.amber.withValues(alpha: 0.3)
                          : AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _activeMode == 'due' ? 'DUE' : 'CRAM',
                    style: AppTypography.caption.copyWith(
                      color: _activeMode == 'due' ? AppColors.amber : AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                Text('${_currentIndex + 1} / ${_cards!.length}', style: AppTypography.h2),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surface,
                color: _activeMode == 'due' ? AppColors.amber : AppColors.accent,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.timerDuration != null)
              LinearProgressIndicator(
                value: _timeRemaining / widget.timerDuration!,
                backgroundColor: AppColors.surface,
                color: _timeRemaining <= 3 ? AppColors.error : AppColors.success,
                minHeight: 4,
              ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _selectedOptionIndex = null;
                    _isProcessing = false;
                  });
                  _startTimer();
                },
                itemCount: _cards!.length,
                itemBuilder: (context, index) {
                  final card = _cards![index];
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildCardView(card),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardView(CardModel card) {
    if (card is FlashcardModel) {
      return Column(
        children: [
          Expanded(
            child: FlashCard(
              frontText: card.front,
              backText: card.back,
              forceReveal: _forceReveal,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  'Fail',
                  LucideIcons.x,
                  AppColors.error,
                  () => _handleAnswer(false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionBtn(
                  'Pass',
                  LucideIcons.check,
                  AppColors.success,
                  () => _handleAnswer(true),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (card is MCQModel) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  card.question,
                  style: AppTypography.h1,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(card.options.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: MCQOption(
                letter: String.fromCharCode(65 + i),
                text: card.options[i],
                state: (_selectedOptionIndex == null && !_isTimedOut)
                    ? MCQOptionState.idle
                    : (i == card.correctIndex
                        ? MCQOptionState.correct
                        : (i == _selectedOptionIndex
                            ? MCQOptionState.incorrect
                            : MCQOptionState.idle)),
                onTap: () {
                  if (_selectedOptionIndex != null) return; // Prevent double taps
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedOptionIndex = i;
                  });
                  
                  final passed = (i == card.correctIndex);
                  // Give user 1 second to see if they were right before advancing
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) _handleAnswer(passed);
                  });
                },
              ),
            );
          }),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.h2.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
