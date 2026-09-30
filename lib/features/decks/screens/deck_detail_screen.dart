import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/spaced_repetition.dart';
import '../../../core/widgets/recall_button.dart';
import '../../../core/widgets/recall_field.dart';
import '../../study/study_service.dart';
import '../../study/models/card_model.dart';
import '../models/deck_model.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;

  const DeckDetailScreen({super.key, required this.deckId});

  /// Calculates mastery percentage based on spaced repetition progress.
  /// - Repetitions >= 2 or Interval >= 6 days: Mastered (1.0)
  /// - Repetitions == 1 or Interval >= 1 day: Learning (0.5)
  /// - Repetitions == 0: New / Unstudied (0.0)
  static int calculateMasteryPercentage(List<CardModel> cards) {
    if (cards.isEmpty) return 0;
    double score = 0;
    for (final card in cards) {
      if (card.repetitions >= 2 || card.interval >= 6) {
        score += 1.0;
      } else if (card.repetitions == 1 || card.interval >= 1) {
        score += 0.5;
      }
    }
    return ((score / cards.length) * 100).round().clamp(0, 100);
  }

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  DeckModel? _deck;
  List<CardModel>? _cards;
  bool _isLoading = true;
  String? _error;
  int _masteryPercent = 0;
  final Set<int> _revealedAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadDeckDetails();
  }

  Future<void> _loadDeckDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deckService = context.read<DeckService>();
      final studyService = context.read<StudyService>();

      final deck = await deckService.getDeckById(widget.deckId);
      if (deck == null) {
        if (mounted) {
          setState(() {
            _error = 'Deck not found.';
            _isLoading = false;
          });
        }
        return;
      }

      final cards = await studyService.getCardsForDeck(deck.id, deck.isFlashcard);
      final mastery = DeckDetailScreen.calculateMasteryPercentage(cards);

      if (mounted) {
        setState(() {
          _deck = deck;
          _cards = cards;
          _masteryPercent = mastery;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load deck: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showMoreOptions() {
    if (_deck == null) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = _deck!.createdBy == currentUid || _deck!.createdBy.isEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deck!.title,
                        style: AppTypography.h2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_deck!.tag} • ${_deck!.totalCards} cards',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                ListTile(
                  leading: Icon(LucideIcons.share2, color: AppColors.accent),
                  title: Text('Share Deck', style: AppTypography.bodyMedium),
                  subtitle: Text('Copy deck summary to clipboard', style: AppTypography.caption),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(
                      text: 'Check out "${_deck!.title}" on Recall!\nTag: #${_deck!.tag}\nCards: ${_deck!.totalCards}\nDescription: ${_deck!.description}',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deck details copied to clipboard!'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                if (isOwner) ...[
                  ListTile(
                    leading: Icon(LucideIcons.pencil, color: AppColors.accent),
                    title: Text('Edit Deck Details', style: AppTypography.bodyMedium),
                    subtitle: Text('Change title, description, tag, or visibility', style: AppTypography.caption),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showEditDeckBottomSheet();
                    },
                  ),
                  ListTile(
                    leading: Icon(LucideIcons.plusCircle, color: AppColors.accent),
                    title: Text('Add Card', style: AppTypography.bodyMedium),
                    subtitle: Text('Append a new card to this deck', style: AppTypography.caption),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showAddCardBottomSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                    title: Text(
                      'Delete Deck',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                    ),
                    subtitle: Text(
                      'Permanently remove this deck and cards',
                      style: AppTypography.caption,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDeleteDeck();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDeckBottomSheet() {
    if (_deck == null) return;

    final titleController = TextEditingController(text: _deck!.title);
    final tagController = TextEditingController(text: _deck!.tag);
    final descController = TextEditingController(text: _deck!.description);
    bool isPublic = _deck!.isPublic;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Edit Deck Details', style: AppTypography.h2),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 20),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RecallField(
                        controller: titleController,
                        label: 'Deck Title (e.g. Organic Chemistry III)',
                      ),
                      const SizedBox(height: 12),
                      RecallField(
                        controller: tagController,
                        label: 'Tag / Subject (e.g. Chemistry)',
                      ),
                      const SizedBox(height: 12),
                      RecallField(
                        controller: descController,
                        label: 'Description (What does this deck cover?)',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Public Deck',
                                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Allow community learners to discover and import this deck in Explore',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isPublic,
                              activeThumbColor: AppColors.accent,
                              onChanged: (val) => setSheetState(() => isPublic = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isSaving)
                        Center(child: CircularProgressIndicator(color: AppColors.accent))
                      else
                        RecallButton(
                          label: 'Save Changes',
                          icon: LucideIcons.check,
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Deck title cannot be empty.'),
                                  backgroundColor: AppColors.amber,
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSaving = true);

                            try {
                              final deckService = context.read<DeckService>();
                              await deckService.updateDeckMetadata(
                                deckId: _deck!.id,
                                title: title,
                                description: descController.text.trim(),
                                tag: tagController.text.trim().isEmpty ? 'General' : tagController.text.trim(),
                                isPublic: isPublic,
                              );

                              if (!mounted) return;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Deck updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );

                              _loadDeckDetails();
                            } catch (e) {
                              if (!mounted) return;
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update deck: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDeck() {
    if (_deck == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Text('Delete Deck?', style: AppTypography.h2),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${_deck!.title}"? This will permanently erase the deck and all ${_cards?.length ?? _deck!.totalCards} cards. This cannot be undone.',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final deckService = context.read<DeckService>();
                await deckService.deleteDeck(_deck!.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deck "${_deck!.title}" deleted successfully.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.pop();
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAddCardBottomSheet() {
    if (_deck == null) return;
    final isFlashcard = _deck!.isFlashcard;

    final promptController = TextEditingController();
    final answerController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFlashcard ? 'Add Flashcard' : 'Add Quiz Question',
                            style: AppTypography.h2,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFlashcard ? 'Flashcard' : 'MCQ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RecallField(
                        controller: promptController,
                        label: isFlashcard ? 'Front (Question / Prompt)' : 'Question',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      if (isFlashcard)
                        RecallField(
                          controller: answerController,
                          label: 'Back (Answer / Explanation)',
                          maxLines: 3,
                        )
                      else ...[
                        Text(
                          'Quiz Options (Tap letter to mark correct answer):',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int optIdx = 0; optIdx < 4; optIdx++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => setSheetState(() => correctIndex = optIdx),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: correctIndex == optIdx
                                          ? AppColors.success.withValues(alpha: 0.2)
                                          : AppColors.background,
                                      border: Border.all(
                                        color: correctIndex == optIdx
                                            ? AppColors.success
                                            : AppColors.textMuted.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: correctIndex == optIdx
                                        ? const Icon(LucideIcons.check, size: 16, color: AppColors.success)
                                        : Center(
                                            child: Text(
                                              String.fromCharCode(65 + optIdx),
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: RecallField(
                                    controller: optionControllers[optIdx],
                                    label: 'Option ${String.fromCharCode(65 + optIdx)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      if (isSaving)
                        Center(child: CircularProgressIndicator(color: AppColors.accent))
                      else
                        RecallButton(
                          label: 'Add Card to Deck',
                          icon: LucideIcons.plus,
                          onPressed: () async {
                            final prompt = promptController.text.trim();
                            if (prompt.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a prompt or question.'),
                                  backgroundColor: AppColors.amber,
                                ),
                              );
                              return;
                            }

                            if (isFlashcard) {
                              final answer = answerController.text.trim();
                              if (answer.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter an answer.'),
                                    backgroundColor: AppColors.amber,
                                  ),
                                );
                                return;
                              }
                            } else {
                              final options = optionControllers.map((c) => c.text.trim()).toList();
                              if (options.any((opt) => opt.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all 4 quiz choices.'),
                                    backgroundColor: AppColors.amber,
                                  ),
                                );
                                return;
                              }
                            }

                            setSheetState(() => isSaving = true);

                            try {
                              final deckService = context.read<DeckService>();
                              final now = DateTime.now();
                              final cardId = FirebaseFirestore.instance.collection('temp').doc().id;

                              final CardModel newCard;
                              if (isFlashcard) {
                                newCard = FlashcardModel(
                                  id: cardId,
                                  deckId: _deck!.id,
                                  front: prompt,
                                  back: answerController.text.trim(),
                                  nextReviewDate: now,
                                );
                              } else {
                                newCard = MCQModel(
                                  id: cardId,
                                  deckId: _deck!.id,
                                  question: prompt,
                                  options: optionControllers.map((c) => c.text.trim()).toList(),
                                  correctIndex: correctIndex,
                                  nextReviewDate: now,
                                );
                              }

                              await deckService.addCardToDeck(_deck!.id, newCard);

                              if (!mounted) return;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added new card to "${_deck!.title}"!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );

                              _loadDeckDetails();
                            } catch (e) {
                              if (!mounted) return;
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add card: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCardBottomSheet(CardModel card) {
    if (_deck == null) return;
    final isFlashcard = card is FlashcardModel;
    final flashcard = card is FlashcardModel ? card : null;
    final mcq = card is MCQModel ? card : null;

    final promptController = TextEditingController(
      text: flashcard != null ? flashcard.front : (mcq?.question ?? ''),
    );
    final answerController = TextEditingController(
      text: flashcard != null ? flashcard.back : '',
    );
    final optionControllers = List.generate(4, (i) {
      if (mcq != null) {
        return TextEditingController(text: i < mcq.options.length ? mcq.options[i] : '');
      }
      return TextEditingController();
    });
    int correctIndex = mcq?.correctIndex ?? 0;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFlashcard ? 'Edit Flashcard' : 'Edit Quiz Question',
                            style: AppTypography.h2,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFlashcard ? 'Flashcard' : 'MCQ',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RecallField(
                        controller: promptController,
                        label: isFlashcard ? 'Front (Question / Prompt)' : 'Question',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      if (isFlashcard)
                        RecallField(
                          controller: answerController,
                          label: 'Back (Answer / Explanation)',
                          maxLines: 3,
                        )
                      else ...[
                        Text(
                          'Quiz Options (Tap letter to mark correct answer):',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int optIdx = 0; optIdx < 4; optIdx++) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => setSheetState(() => correctIndex = optIdx),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: correctIndex == optIdx
                                          ? AppColors.success.withValues(alpha: 0.2)
                                          : AppColors.background,
                                      border: Border.all(
                                        color: correctIndex == optIdx
                                            ? AppColors.success
                                            : AppColors.textMuted.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: correctIndex == optIdx
                                        ? const Icon(LucideIcons.check, size: 16, color: AppColors.success)
                                        : Center(
                                            child: Text(
                                              String.fromCharCode(65 + optIdx),
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: RecallField(
                                    controller: optionControllers[optIdx],
                                    label: 'Option ${String.fromCharCode(65 + optIdx)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      if (isSaving)
                        Center(child: CircularProgressIndicator(color: AppColors.accent))
                      else
                        RecallButton(
                          label: 'Save Card Changes',
                          icon: LucideIcons.check,
                          onPressed: () async {
                            final prompt = promptController.text.trim();
                            if (prompt.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a prompt or question.'),
                                  backgroundColor: AppColors.amber,
                                ),
                              );
                              return;
                            }

                            if (isFlashcard) {
                              final answer = answerController.text.trim();
                              if (answer.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter an answer.'),
                                    backgroundColor: AppColors.amber,
                                  ),
                                );
                                return;
                              }
                            } else {
                              final options = optionControllers.map((c) => c.text.trim()).toList();
                              if (options.any((opt) => opt.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all 4 quiz choices.'),
                                    backgroundColor: AppColors.amber,
                                  ),
                                );
                                return;
                              }
                            }

                            setSheetState(() => isSaving = true);

                            try {
                              final deckService = context.read<DeckService>();
                              final CardModel updatedCard;
                              if (card is FlashcardModel) {
                                updatedCard = card.copyWith(
                                  front: prompt,
                                  back: answerController.text.trim(),
                                );
                              } else if (card is MCQModel) {
                                updatedCard = card.copyWith(
                                  question: prompt,
                                  options: optionControllers.map((c) => c.text.trim()).toList(),
                                  correctIndex: correctIndex,
                                );
                              } else {
                                return;
                              }

                              await deckService.updateCard(_deck!.id, updatedCard);

                              if (!mounted) return;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Card updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );

                              _loadDeckDetails();
                            } catch (e) {
                              if (!mounted) return;
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update card: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCard(CardModel card) {
    if (_deck == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(LucideIcons.trash2, color: AppColors.error, size: 22),
              const SizedBox(width: 8),
              Text('Delete Card?', style: AppTypography.h2),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this card? This action cannot be undone.',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final deckService = context.read<DeckService>();
                  await deckService.deleteCard(_deck!.id, card.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Card deleted successfully.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _loadDeckDetails();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete card: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreVertical),
            tooltip: 'Deck options',
            onPressed: _deck != null ? _showMoreOptions : null,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null || _deck == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_error ?? 'Deck not found', style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDeckDetails,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                child: const Text('Retry', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    final deck = _deck!;
    final cards = _cards ?? [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = deck.createdBy == currentUid || deck.createdBy.isEmpty;
    final breakdown = SpacedRepetition.getBreakdown(cards);

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _loadDeckDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 150.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: deck.isFlashcard
                    ? AppColors.amber.withValues(alpha: 0.15)
                    : AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: deck.isFlashcard
                      ? AppColors.amber.withValues(alpha: 0.3)
                      : AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                deck.tag.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: deck.isFlashcard ? AppColors.amber : AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(deck.title, style: AppTypography.display),
            const SizedBox(height: 8),
            Text(
              'Created by ${deck.author.isNotEmpty ? deck.author : "Learner"}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 20),
            Text(deck.description, style: AppTypography.body),
            const SizedBox(height: 28),

            // Stat Cards Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Cards', cards.length.toString()),
                      _buildDivider(),
                      _buildStatColumn('Format', deck.isFlashcard ? 'Flashcard' : 'Quiz (MCQ)'),
                      _buildDivider(),
                      _buildStatColumn('Mastery', '$_masteryPercent%'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Visual Mastery Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _masteryPercent / 100.0,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _masteryPercent >= 80
                            ? AppColors.success
                            : (_masteryPercent >= 40 ? AppColors.accent : AppColors.amber),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Queue Breakdown Pills
                  Row(
                    children: [
                      Expanded(
                        child: _buildQueuePill(
                          'Due',
                          '${breakdown['due'] ?? 0}',
                          AppColors.amber,
                          LucideIcons.clock,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQueuePill(
                          'Learning',
                          '${breakdown['learning'] ?? 0}',
                          Colors.lightBlueAccent,
                          LucideIcons.bookOpen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQueuePill(
                          'Mastered',
                          '${breakdown['mastered'] ?? 0}',
                          AppColors.success,
                          LucideIcons.checkCircle2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Card Preview Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cards in Deck', style: AppTypography.h2),
                Row(
                  children: [
                    if (isOwner) ...[
                      InkWell(
                        onTap: _showAddCardBottomSheet,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus, size: 14, color: AppColors.accent),
                              const SizedBox(width: 4),
                              Text(
                                'Add Card',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cards.length} Total',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cards Preview List
            if (cards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No cards found in this deck.',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildCardPreviewTile(cards[index], index);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _startStudySession(String mode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('Select Pacing', style: AppTypography.h2),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(LucideIcons.coffee, color: AppColors.accent),
                  title: Text('Standard Mode', style: AppTypography.bodyMedium),
                  subtitle: Text('No timer. Study at your own pace.', style: AppTypography.caption),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/study/${_deck!.id}?mode=$mode').then((_) {
                      if (mounted) _loadDeckDetails();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.timer, color: AppColors.amber),
                  title: Text('Speed Run (10s)', style: AppTypography.bodyMedium),
                  subtitle: Text('10 seconds per card.', style: AppTypography.caption),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/study/${_deck!.id}?mode=$mode&timer=10').then((_) {
                      if (mounted) _loadDeckDetails();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.timer, color: AppColors.error),
                  title: Text('Speed Run (15s)', style: AppTypography.bodyMedium),
                  subtitle: Text('15 seconds per card.', style: AppTypography.caption),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/study/${_deck!.id}?mode=$mode&timer=15').then((_) {
                      if (mounted) _loadDeckDetails();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.timer, color: AppColors.error),
                  title: Text('Speed Run (30s)', style: AppTypography.bodyMedium),
                  subtitle: Text('30 seconds per card.', style: AppTypography.caption),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/study/${_deck!.id}?mode=$mode&timer=30').then((_) {
                      if (mounted) _loadDeckDetails();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (_deck == null || _isLoading) return const SizedBox.shrink();

    final cards = _cards ?? [];
    final hasCards = cards.isNotEmpty;
    final dueCards = SpacedRepetition.filterDueCards(cards);
    final dueCount = dueCards.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasCards)
              const RecallButton(
                label: 'Deck Has No Cards',
                icon: LucideIcons.play,
                onPressed: null,
              )
            else if (dueCount > 0) ...[
              RecallButton(
                label: 'Study Due ($dueCount ${dueCount == 1 ? 'Card' : 'Cards'})',
                icon: LucideIcons.play,
                onPressed: () => _startStudySession('due'),
              ),
              const SizedBox(height: 8),
              RecallButton(
                label: 'Cram All (${cards.length} Cards)',
                icon: LucideIcons.zap,
                variant: RecallButtonVariant.secondary,
                onPressed: () => _startStudySession('all'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.sparkles, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'All caught up for today!',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              RecallButton(
                label: 'Cram All (${cards.length} Cards)',
                icon: LucideIcons.zap,
                onPressed: () => _startStudySession('all'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardPreviewTile(CardModel card, int index) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = _deck?.createdBy == currentUid || (_deck?.createdBy.isEmpty ?? false);
    final isRevealed = _revealedAnswers.contains(index);

    // Spaced Repetition status tag
    String statusLabel = 'New';
    Color statusColor = AppColors.textMuted;
    if (card.repetitions >= 2 || card.interval >= 6) {
      statusLabel = 'Mastered';
      statusColor = AppColors.success;
    } else if (card.repetitions == 1 || card.interval >= 1) {
      statusLabel = 'Learning';
      statusColor = AppColors.accent;
    }

    final promptText = card is FlashcardModel
        ? card.front
        : (card is MCQModel ? card.question : '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Card #${index + 1}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showEditCardBottomSheet(card),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          LucideIcons.pencil,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmDeleteCard(card),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          LucideIcons.trash2,
                          size: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question / Prompt
          Text(
            promptText,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Flashcard answer or MCQ options
          if (card is FlashcardModel) ...[
            InkWell(
              onTap: () {
                setState(() {
                  if (isRevealed) {
                    _revealedAnswers.remove(index);
                  } else {
                    _revealedAnswers.add(index);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRevealed
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : AppColors.textMuted.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRevealed ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 14,
                      color: isRevealed ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRevealed ? card.back : 'Tap to reveal answer',
                        style: AppTypography.caption.copyWith(
                          color: isRevealed ? AppColors.textPrimary : AppColors.textMuted,
                          fontStyle: isRevealed ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (card is MCQModel) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: card.options.asMap().entries.map((entry) {
                final optIdx = entry.key;
                final optText = entry.value;
                final isCorrect = optIdx == card.correctIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCorrect
                                ? AppColors.success
                                : AppColors.textMuted.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: isCorrect
                              ? const Icon(LucideIcons.check, size: 12, color: AppColors.success)
                              : Text(
                                  String.fromCharCode(65 + optIdx),
                                  style: AppTypography.caption.copyWith(fontSize: 10),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          optText,
                          style: AppTypography.caption.copyWith(
                            color: isCorrect ? AppColors.success : AppColors.textMuted,
                            fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.textMuted.withValues(alpha: 0.15),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.h2.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildQueuePill(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

