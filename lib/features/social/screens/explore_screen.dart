import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/deck_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/deck_card.dart';
import '../../decks/models/deck_model.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  /// Pure filtering function to easily support unit and widget testing.
  static List<DeckModel> filterDecks({
    required List<DeckModel> allDecks,
    required String query,
    required String selectedTag,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final cleanTag = selectedTag.trim().toLowerCase();

    return allDecks.where((deck) {
      final matchesTag = cleanTag == 'all' || deck.tag.toLowerCase() == cleanTag;
      if (!matchesTag) return false;

      if (cleanQuery.isEmpty) return true;

      final matchesTitle = deck.title.toLowerCase().contains(cleanQuery);
      final matchesAuthor = deck.author.toLowerCase().contains(cleanQuery);
      final matchesTagQuery = deck.tag.toLowerCase().contains(cleanQuery);
      final matchesDesc = deck.description.toLowerCase().contains(cleanQuery);

      return matchesTitle || matchesAuthor || matchesTagQuery || matchesDesc;
    }).toList();
  }

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = 'All';
  final Set<String> _importingDeckIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedTag = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await context.read<DeckService>().refreshDecks();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore', style: AppTypography.display),
                const SizedBox(height: 8),
                Text(
                  'Discover and import public decks curated by the community.',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),

                // Interactive Search Bar
                _buildSearchBar(),
                const SizedBox(height: 20),

                // Horizontal Category / Tag Filter Chips
                _buildCategoryChips(),
                const SizedBox(height: 28),

                // Decks Header & Filtered Results
                _buildExploreSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasQuery
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.textMuted.withValues(alpha: 0.12),
        ),
        boxShadow: hasQuery
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: _searchController,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Search decks, topics, or authors...',
          hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
          prefixIcon: const Icon(LucideIcons.search, color: AppColors.textMuted, size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.textMuted, size: 18),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Consumer<DeckService>(
      builder: (context, deckService, _) {
        final exploreDecks = deckService.exploreDecks;

        // Collect unique tags from active public decks, formatted neatly
        final Set<String> availableTags = {'All'};
        for (final deck in exploreDecks) {
          if (deck.tag.trim().isNotEmpty) {
            final formatted = deck.tag.trim().substring(0, 1).toUpperCase() +
                deck.tag.trim().substring(1).toLowerCase();
            availableTags.add(formatted);
          }
        }

        // Add standard fallback tags if catalog is growing
        availableTags.addAll(['Flutter', 'Medicine', 'Science', 'Languages', 'Technology']);

        final tagsList = availableTags.toList();

        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tagsList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tagsList[index];
              final isSelected = _selectedTag.toLowerCase() == tag.toLowerCase();

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedTag = tag;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textMuted.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? AppColors.accent : AppColors.textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExploreSection() {
    return Consumer<DeckService>(
      builder: (context, deckService, child) {
        if (deckService.isLoading && deckService.exploreDecks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        final filteredDecks = ExploreScreen.filterDecks(
          allDecks: deckService.exploreDecks,
          query: _searchController.text,
          selectedTag: _selectedTag,
        );

        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final userDecks = deckService.yourDecks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Community Decks', style: AppTypography.h2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredDecks.length} Decks',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (filteredDecks.isEmpty)
              _buildEmptySearchResults()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredDecks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final deck = filteredDecks[index];
                  final isOwner = deck.createdBy.isNotEmpty && deck.createdBy == currentUid;
                  
                  // Detect whether the user has already imported this deck
                  final isAlreadyImported = userDecks.any((d) =>
                      d.id == deck.id ||
                      d.title.trim().toLowerCase() == '${deck.title.trim()} (imported)'.toLowerCase() ||
                      (d.title.trim().toLowerCase() == deck.title.trim().toLowerCase() && d.createdBy == currentUid));

                  final isImporting = _importingDeckIds.contains(deck.id);

                  // Determine action button properties
                  String? actionLabel;
                  Color? actionColor;
                  VoidCallback? onAction;

                  if (isOwner) {
                    actionLabel = 'Your Deck';
                    actionColor = AppColors.textMuted;
                    onAction = null;
                  } else if (isAlreadyImported) {
                    actionLabel = 'Imported';
                    actionColor = AppColors.success;
                    onAction = null;
                  } else {
                    actionLabel = isImporting ? 'Importing' : 'Import';
                    actionColor = AppColors.accent;
                    onAction = () async {
                      setState(() => _importingDeckIds.add(deck.id));
                      try {
                        await deckService.importDeck(deck.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deck "${deck.title}" imported to Your Decks!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _importingDeckIds.remove(deck.id));
                        }
                      }
                    };
                  }

                  return DeckCard(
                    title: deck.title,
                    subtitle: deck.author.isNotEmpty ? deck.author : 'Scholar',
                    totalCards: deck.totalCards,
                    tag: deck.tag,
                    isFlashcard: deck.isFlashcard,
                    actionLabel: actionLabel,
                    actionColor: actionColor,
                    isActionLoading: isImporting,
                    onAction: onAction,
                    onTap: () {
                      context.push('/deck/${deck.id}');
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptySearchResults() {
    final hasFilters = _searchController.text.trim().isNotEmpty || _selectedTag != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.compass, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching decks found',
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try searching with different keywords or choosing another category tag.'
                : 'No public community decks are currently available.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          if (hasFilters) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}

