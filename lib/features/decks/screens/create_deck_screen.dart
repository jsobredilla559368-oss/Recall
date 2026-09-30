import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/services/document_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/recall_field.dart';
import '../../../core/widgets/recall_button.dart';
import '../../study/models/card_model.dart';
import '../models/deck_model.dart';

class ManualCardDraft {
  final TextEditingController promptController;
  final TextEditingController answerController;
  final List<TextEditingController> optionControllers;
  int correctIndex;

  ManualCardDraft({
    String prompt = '',
    String answer = '',
    List<String>? options,
    this.correctIndex = 0,
  })  : promptController = TextEditingController(text: prompt),
        answerController = TextEditingController(text: answer),
        optionControllers = (options != null && options.length == 4)
            ? options.map((opt) => TextEditingController(text: opt)).toList()
            : List.generate(4, (i) => TextEditingController(text: (options != null && i < options.length) ? options[i] : ''));

  void dispose() {
    promptController.dispose();
    answerController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isGenerating = false;
  bool _useFile = false;
  bool _isFlashcard = true;
  int _cardCount = 10;

  // New Mode & Review States
  bool _isManualMode = false;
  bool _isReviewingAI = false;
  DeckModel? _aiGeneratedDeck;
  final List<ManualCardDraft> _aiReviewedCards = [];
  bool _isSavingDeck = false;

  // Manual Builder Draft Cards
  final List<ManualCardDraft> _manualCards = [
    ManualCardDraft(),
  ];

  // File Extraction State
  bool _isExtractingFile = false;
  DocumentExtractResult? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _contentController.dispose();
    for (final card in _manualCards) {
      card.dispose();
    }
    for (final card in _aiReviewedCards) {
      card.dispose();
    }
    super.dispose();
  }

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get _charCount => _contentController.text.length;

  Future<void> _handlePasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        final pasted = data.text!.trim();
        setState(() {
          _contentController.text = pasted;

          // Auto-suggest title if currently empty
          if (_titleController.text.trim().isEmpty) {
            final firstLine = pasted.split('\n').first.trim();
            final candidate =
                firstLine.length > 35 ? '${firstLine.substring(0, 32)}...' : firstLine;
            _titleController.text =
                candidate.replaceAll(RegExp(r'[#*_\-]'), '').trim();
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pasted $_wordCount words from clipboard!'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty or contains non-text data.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error reading clipboard: $e');
    }
  }

  Future<void> _handlePickFile() async {
    setState(() => _isExtractingFile = true);
    try {
      final result = await DocumentService.pickAndExtractDocument();
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _selectedDocument = result;

          // Auto-fill title if empty
          if (_titleController.text.trim().isEmpty) {
            final cleanName = result.fileName
                .replaceAll(
                    RegExp(r'\.(pdf|txt|docx|doc|md)$', caseSensitive: false), '')
                .replaceAll(RegExp(r'[_\-]'), ' ')
                .trim();
            if (cleanName.isNotEmpty) {
              _titleController.text = cleanName;
            }
          }
        });

        if (result.warning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.warning!),
              backgroundColor: AppColors.amber,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Extracted ${result.wordCount} words from ${result.fileName}!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to read document: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExtractingFile = false);
      }
    }
  }

  Future<void> _handleGenerate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a deck title')),
      );
      return;
    }

    if (_useFile) {
      if (_selectedDocument == null || !_selectedDocument!.hasText) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please upload a PDF or text file with readable text first.'),
            backgroundColor: AppColors.amber,
          ),
        );
        return;
      }
    }

    setState(() => _isGenerating = true);

    try {
      final aiService = context.read<AIService>();

      final tag = _tagController.text.trim().isEmpty
          ? 'General'
          : _tagController.text.trim();
      final sourceText = _useFile
          ? _selectedDocument!.extractedText
          : _contentController.text.trim();

      final result = await aiService.generateDeckFromText(
        title: title,
        text: sourceText,
        tag: tag,
        isFlashcard: _isFlashcard,
        cardCount: _cardCount,
      );

      if (!mounted) return;

      for (final draft in _aiReviewedCards) {
        draft.dispose();
      }
      _aiReviewedCards.clear();

      for (final c in result.cards) {
        if (c is FlashcardModel) {
          _aiReviewedCards.add(ManualCardDraft(
            prompt: c.front,
            answer: c.back,
          ));
        } else if (c is MCQModel) {
          _aiReviewedCards.add(ManualCardDraft(
            prompt: c.question,
            options: c.options,
            correctIndex: c.correctIndex,
          ));
        } else {
          _aiReviewedCards.add(ManualCardDraft());
        }
      }

      setState(() {
        _isGenerating = false;
        _isReviewingAI = true;
        _aiGeneratedDeck = result.deck;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Synthesized ${result.cards.length} cards via ${result.providerUsed}! Review and edit before saving.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate deck: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSaveReviewedAIDeck() async {
    if (_aiReviewedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deck must have at least one card to save.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    for (int i = 0; i < _aiReviewedCards.length; i++) {
      final draft = _aiReviewedCards[i];
      if (draft.promptController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card #${i + 1} is missing a question or prompt.'),
            backgroundColor: AppColors.amber,
          ),
        );
        return;
      }
      if (_isFlashcard) {
        if (draft.answerController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card #${i + 1} is missing an answer.'),
              backgroundColor: AppColors.amber,
            ),
          );
          return;
        }
      } else {
        final options = draft.optionControllers.map((c) => c.text.trim()).toList();
        if (options.any((opt) => opt.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card #${i + 1} must have all 4 quiz choices filled.'),
              backgroundColor: AppColors.amber,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSavingDeck = true);

    try {
      final deckService = context.read<DeckService>();
      final currentUser = FirebaseAuth.instance.currentUser;
      final deckId = _aiGeneratedDeck?.id ?? FirebaseFirestore.instance.collection('decks').doc().id;
      final now = DateTime.now();

      final List<CardModel> finalCards = [];
      for (final draft in _aiReviewedCards) {
        final cardId = FirebaseFirestore.instance.collection('temp').doc().id;
        if (_isFlashcard) {
          finalCards.add(FlashcardModel(
            id: cardId,
            deckId: deckId,
            front: draft.promptController.text.trim(),
            back: draft.answerController.text.trim(),
            nextReviewDate: now,
          ));
        } else {
          finalCards.add(MCQModel(
            id: cardId,
            deckId: deckId,
            question: draft.promptController.text.trim(),
            options: draft.optionControllers.map((c) => c.text.trim()).toList(),
            correctIndex: draft.correctIndex,
            nextReviewDate: now,
          ));
        }
      }

      final deckToSave = (_aiGeneratedDeck ?? DeckModel(
        id: deckId,
        title: _titleController.text.trim(),
        description: 'AI-generated study deck on ${_tagController.text.trim()}',
        totalCards: finalCards.length,
        tag: _tagController.text.trim().isEmpty ? 'General' : _tagController.text.trim(),
        isFlashcard: _isFlashcard,
        author: currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Learner',
        createdBy: currentUser?.uid ?? '',
        createdAt: now,
        isPublic: false,
      )).copyWith(
        id: deckId,
        totalCards: finalCards.length,
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
      );

      final createdDeck = await deckService.createDeck(deckToSave, finalCards);

      if (!mounted) return;
      setState(() => _isSavingDeck = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${createdDeck.title}" with ${finalCards.length} cards!'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pushReplacement('/deck/${createdDeck.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingDeck = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save deck: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSaveManualDeck() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a deck title.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    if (_manualCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one card.'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    for (int i = 0; i < _manualCards.length; i++) {
      final draft = _manualCards[i];
      if (draft.promptController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card #${i + 1} is missing a question or prompt.'),
            backgroundColor: AppColors.amber,
          ),
        );
        return;
      }

      if (_isFlashcard) {
        if (draft.answerController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card #${i + 1} is missing an answer.'),
              backgroundColor: AppColors.amber,
            ),
          );
          return;
        }
      } else {
        final options = draft.optionControllers.map((c) => c.text.trim()).toList();
        if (options.any((opt) => opt.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Card #${i + 1} must have all 4 quiz choices filled.'),
              backgroundColor: AppColors.amber,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSavingDeck = true);

    try {
      final deckService = context.read<DeckService>();
      final currentUser = FirebaseAuth.instance.currentUser;
      final deckId = FirebaseFirestore.instance.collection('decks').doc().id;
      final tag = _tagController.text.trim().isEmpty ? 'General' : _tagController.text.trim();
      final now = DateTime.now();

      final List<CardModel> finalCards = [];
      for (final draft in _manualCards) {
        final cardId = FirebaseFirestore.instance.collection('temp').doc().id;
        if (_isFlashcard) {
          finalCards.add(FlashcardModel(
            id: cardId,
            deckId: deckId,
            front: draft.promptController.text.trim(),
            back: draft.answerController.text.trim(),
            nextReviewDate: now,
          ));
        } else {
          finalCards.add(MCQModel(
            id: cardId,
            deckId: deckId,
            question: draft.promptController.text.trim(),
            options: draft.optionControllers.map((c) => c.text.trim()).toList(),
            correctIndex: draft.correctIndex,
            nextReviewDate: now,
          ));
        }
      }

      final deck = DeckModel(
        id: deckId,
        title: title,
        description: 'Custom ${_isFlashcard ? "flashcard" : "quiz"} deck on $tag',
        totalCards: finalCards.length,
        tag: tag,
        isFlashcard: _isFlashcard,
        author: currentUser?.displayName ?? currentUser?.email?.split('@').first ?? 'Learner',
        createdBy: currentUser?.uid ?? '',
        createdAt: now,
        isPublic: false,
      );

      final createdDeck = await deckService.createDeck(deck, finalCards);

      if (!mounted) return;
      setState(() => _isSavingDeck = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created "${createdDeck.title}" with ${finalCards.length} cards!'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pushReplacement('/deck/${createdDeck.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingDeck = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create deck: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildModeSwitcher() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isManualMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isManualMode ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: !_isManualMode ? Colors.black : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Synthesis',
                      style: AppTypography.bodyMedium.copyWith(
                        color: !_isManualMode ? Colors.black : AppColors.textMuted,
                        fontWeight: !_isManualMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isManualMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isManualMode ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.penTool,
                      size: 16,
                      color: _isManualMode ? Colors.black : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manual Builder',
                      style: AppTypography.bodyMedium.copyWith(
                        color: _isManualMode ? Colors.black : AppColors.textMuted,
                        fontWeight: _isManualMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDraftTile({
    required ManualCardDraft draft,
    required int index,
    required bool isFlashcard,
    required VoidCallback onDelete,
    required bool canDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Card #${index + 1}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                  onPressed: onDelete,
                  tooltip: 'Delete Card',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          RecallField(
            controller: draft.promptController,
            label: isFlashcard ? 'Front (Question / Prompt)' : 'Question',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (isFlashcard)
            RecallField(
              controller: draft.answerController,
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
                      onTap: () => setState(() => draft.correctIndex = optIdx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: draft.correctIndex == optIdx
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.background,
                          border: Border.all(
                            color: draft.correctIndex == optIdx
                                ? AppColors.success
                                : AppColors.textMuted.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: draft.correctIndex == optIdx
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
                        controller: draft.optionControllers[optIdx],
                        label: 'Option ${String.fromCharCode(65 + optIdx)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReviewScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Generated Cards'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Discard & Back',
          onPressed: () {
            showDialog(
              context: context,
              builder: (dCtx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Leave Review?'),
                content: const Text('Returning will discard the generated cards.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Stay'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () {
                      Navigator.pop(dCtx);
                      setState(() => _isReviewingAI = false);
                    },
                    child: const Text('Discard', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.checkCircle2, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_aiReviewedCards.length} Cards Generated',
                            style: AppTypography.h2,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Review prompts, correct any AI hallucinations, or delete cards before saving.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              RecallField(
                controller: _titleController,
                label: 'Deck Title',
              ),
              const SizedBox(height: 24),
              for (int i = 0; i < _aiReviewedCards.length; i++)
                _buildCardDraftTile(
                  draft: _aiReviewedCards[i],
                  index: i,
                  isFlashcard: _isFlashcard,
                  onDelete: () => setState(() {
                    final removed = _aiReviewedCards.removeAt(i);
                    removed.dispose();
                  }),
                  canDelete: _aiReviewedCards.length > 1,
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _aiReviewedCards.add(ManualCardDraft());
                  });
                },
                icon: Icon(LucideIcons.plus, size: 16, color: AppColors.accent),
                label: Text('Add Another Card', style: TextStyle(color: AppColors.accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              if (_isSavingDeck)
                Center(child: CircularProgressIndicator(color: AppColors.accent))
              else
                RecallButton(
                  label: 'Save Deck (${_aiReviewedCards.length} Cards)',
                  icon: LucideIcons.bookmarkCheck,
                  onPressed: _handleSaveReviewedAIDeck,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isReviewingAI) {
      return _buildReviewScaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isManualMode ? 'Manual Deck Builder' : 'Create Deck'),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Mode Switcher: AI Synthesis vs Manual Builder
              _buildModeSwitcher(),

              if (!_isManualMode) ...[
                Text('New AI Deck', style: AppTypography.display),
                const SizedBox(height: 8),
                Text(
                  'Let intelligent AI synthesize study cards from text, notes, or uploaded documents.',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),

                RecallField(
                  controller: _titleController,
                  label: 'Deck Title',
                ),
                const SizedBox(height: 16),
                RecallField(
                  controller: _tagController,
                  label: 'Tag (e.g. Science, Languages)',
                ),
                const SizedBox(height: 24),

                // Card Format Toggle
                Text(
                  'Card Format',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Flashcards',
                        icon: LucideIcons.layers,
                        isSelected: _isFlashcard,
                        onTap: () => setState(() => _isFlashcard = true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Quiz (MCQ)',
                        icon: LucideIcons.helpCircle,
                        isSelected: !_isFlashcard,
                        onTap: () => setState(() => _isFlashcard = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card Quantity Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Number of Cards',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$_cardCount ${_cardCount == 1 ? "Card" : "Cards"}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Custom Slider Component
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surface,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    trackHeight: 6,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _cardCount.toDouble(),
                    min: 1.0,
                    max: 100.0,
                    divisions: 99,
                    onChanged: (val) {
                      setState(() => _cardCount = val.round());
                    },
                  ),
                ),

                // Preset Quick-Select Markers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 min',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      children: [10, 25, 50, 100].map((preset) {
                        final isSelected = _cardCount == preset;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                          child: InkWell(
                            onTap: () => setState(() => _cardCount = preset),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                '$preset',
                                style: AppTypography.caption.copyWith(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    Text(
                      '100 max',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Dynamic Speed/Complexity Indicator
                Row(
                  children: [
                    Icon(
                      _cardCount <= 20 ? LucideIcons.zap : LucideIcons.brain,
                      size: 13,
                      color:
                          _cardCount <= 20 ? AppColors.accent : AppColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _cardCount <= 15
                          ? 'Ultra-fast generation (~1-2s)'
                          : (_cardCount <= 40
                              ? 'Fast synthesis (~3-5s)'
                              : 'Deep knowledge synthesis (~8-15s)'),
                      style: AppTypography.caption.copyWith(
                        color: _cardCount <= 20
                            ? AppColors.accent.withValues(alpha: 0.8)
                            : AppColors.amber.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Content Source Selector
                Text(
                  'Content Source',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Paste Text',
                        icon: LucideIcons.type,
                        isSelected: !_useFile,
                        onTap: () => setState(() => _useFile = false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Upload PDF',
                        icon: LucideIcons.fileText,
                        isSelected: _useFile,
                        onTap: () => setState(() => _useFile = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dynamic Section: Paste Text vs Upload PDF
                if (!_useFile) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Source Notes & Text',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: _handlePasteFromClipboard,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.clipboardPaste,
                                      size: 13, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Paste',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_contentController.text.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  setState(() => _contentController.clear()),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  'Clear',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RecallField(
                    controller: _contentController,
                    label: 'Paste notes, lecture summaries, or article text...',
                    maxLines: 7,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_wordCount words • $_charCount chars',
                        style: AppTypography.caption.copyWith(
                          color: _wordCount > 0
                              ? AppColors.accent
                              : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (_wordCount == 0)
                        Text(
                          'Optional: Can generate from title alone',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  if (_isExtractingFile)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Extracting text from document...',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Parsing multi-page content with high fidelity',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_selectedDocument == null)
                    InkWell(
                      onTap: _handlePickFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.textMuted.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.uploadCloud,
                                  size: 36, color: AppColors.accent),
                            ),
                            const SizedBox(height: 16),
                            Text('Tap to select a file',
                                style: AppTypography.bodyMedium
                                    .copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Supports PDF, TXT, or MD documents',
                                style: AppTypography.caption),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(LucideIcons.fileText,
                                    color: AppColors.accent, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDocument!.fileName,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedDocument!.formattedFileSize} • ${_selectedDocument!.wordCount} words extracted',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.refreshCw,
                                    size: 18, color: AppColors.textMuted),
                                tooltip: 'Replace File',
                                onPressed: _handlePickFile,
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2,
                                    size: 18, color: AppColors.error),
                                tooltip: 'Remove',
                                onPressed: () {
                                  setState(() => _selectedDocument = null);
                                },
                              ),
                            ],
                          ),
                          if (_selectedDocument!.extractedText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '"${_selectedDocument!.extractedText.substring(0, min(140, _selectedDocument!.extractedText.length)).replaceAll('\n', ' ')}..."',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 36),

                if (_isGenerating)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.accent),
                        const SizedBox(height: 16),
                        Text(
                          'Synthesizing $_cardCount ${_isFlashcard ? "flashcards" : "quiz questions"} with AI...',
                          style: TextStyle(
                              color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _useFile
                              ? 'Processing "${_selectedDocument?.fileName}" with Groq...'
                              : 'Generating via Groq ultra-fast AI engine...',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  RecallButton(
                    label:
                        'Generate $_cardCount ${_cardCount == 1 ? "Card" : "Cards"}',
                    onPressed: _handleGenerate,
                    icon: LucideIcons.wand2,
                  ),
              ] else ...[
                // MANUAL DECK BUILDER MODE
                Text('Manual Deck Builder', style: AppTypography.display),
                const SizedBox(height: 8),
                Text(
                  'Craft your own customized deck card by card with full control.',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),

                RecallField(
                  controller: _titleController,
                  label: 'Deck Title',
                ),
                const SizedBox(height: 16),
                RecallField(
                  controller: _tagController,
                  label: 'Tag (e.g. Science, Medicine, Languages)',
                ),
                const SizedBox(height: 24),

                // Card Format Toggle
                Text(
                  'Card Format',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Flashcards',
                        icon: LucideIcons.layers,
                        isSelected: _isFlashcard,
                        onTap: () => setState(() => _isFlashcard = true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceToggle(
                        title: 'Quiz (MCQ)',
                        icon: LucideIcons.helpCircle,
                        isSelected: !_isFlashcard,
                        onTap: () => setState(() => _isFlashcard = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cards (${_manualCards.length})', style: AppTypography.h2),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _manualCards.add(ManualCardDraft());
                        });
                      },
                      icon: Icon(LucideIcons.plus, size: 16, color: AppColors.accent),
                      label: Text('Add Card', style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                for (int i = 0; i < _manualCards.length; i++)
                  _buildCardDraftTile(
                    draft: _manualCards[i],
                    index: i,
                    isFlashcard: _isFlashcard,
                    onDelete: () => setState(() {
                      final removed = _manualCards.removeAt(i);
                      removed.dispose();
                    }),
                    canDelete: _manualCards.length > 1,
                  ),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _manualCards.add(ManualCardDraft());
                    });
                  },
                  icon: Icon(LucideIcons.plus, size: 16, color: AppColors.accent),
                  label: Text('Add Another Card', style: TextStyle(color: AppColors.accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accent.withValues(alpha: 0.4)),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),

                if (_isSavingDeck)
                  Center(child: CircularProgressIndicator(color: AppColors.accent))
                else
                  RecallButton(
                    label: 'Create Deck (${_manualCards.length} ${_manualCards.length == 1 ? "Card" : "Cards"})',
                    icon: LucideIcons.check,
                    onPressed: _handleSaveManualDeck,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceToggle({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.accent : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
