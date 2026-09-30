import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/widgets/deck_card.dart';
import 'package:recall/features/decks/models/deck_model.dart';
import 'package:recall/features/social/screens/explore_screen.dart';

void main() {
  group('ExploreScreen.filterDecks Unit Tests', () {
    final sampleDecks = [
      DeckModel(
        id: '1',
        title: 'Flutter State Management',
        description: 'Deep dive into Provider, Riverpod, and Bloc patterns.',
        totalCards: 15,
        tag: 'Flutter',
        author: 'Isaac Dev',
        createdBy: 'user_1',
        createdAt: DateTime(2026, 1, 1),
        isPublic: true,
      ),
      DeckModel(
        id: '2',
        title: 'Cardiovascular Pathology',
        description: 'ECG anomalies, heart failure mechanics, and pharmacology.',
        totalCards: 30,
        tag: 'Medicine',
        author: 'Dr. Sarah',
        createdBy: 'user_2',
        createdAt: DateTime(2026, 1, 2),
        isPublic: true,
      ),
      DeckModel(
        id: '3',
        title: 'Quantum Physics Fundamentals',
        description: 'Superposition, entanglement, and wave equations.',
        totalCards: 20,
        tag: 'Science',
        author: 'Prof. Davis',
        createdBy: 'user_3',
        createdAt: DateTime(2026, 1, 3),
        isPublic: true,
      ),
      DeckModel(
        id: '4',
        title: 'Spanish Conversational Verbs',
        description: 'Essential irregular verbs and daily life vocabulary.',
        totalCards: 25,
        tag: 'Languages',
        author: 'Maria Elena',
        createdBy: 'user_4',
        createdAt: DateTime(2026, 1, 4),
        isPublic: true,
      ),
    ];

    test('returns all decks when query is empty and tag is All', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: '',
        selectedTag: 'All',
      );
      expect(results.length, equals(4));
    });

    test('filters decks matching title query case-insensitively', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'FLUTTER',
        selectedTag: 'All',
      );
      expect(results.length, equals(1));
      expect(results.first.title, equals('Flutter State Management'));
    });

    test('filters decks matching author query case-insensitively', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'sarah',
        selectedTag: 'All',
      );
      expect(results.length, equals(1));
      expect(results.first.title, equals('Cardiovascular Pathology'));
    });

    test('filters decks matching description query case-insensitively', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'superposition',
        selectedTag: 'All',
      );
      expect(results.length, equals(1));
      expect(results.first.title, equals('Quantum Physics Fundamentals'));
    });

    test('filters decks matching selected category tag', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: '',
        selectedTag: 'Medicine',
      );
      expect(results.length, equals(1));
      expect(results.first.tag, equals('Medicine'));
    });

    test('combines search query and category tag filtering', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'entanglement',
        selectedTag: 'Science',
      );
      expect(results.length, equals(1));
      expect(results.first.title, equals('Quantum Physics Fundamentals'));

      final nonMatchingTag = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'entanglement',
        selectedTag: 'Flutter',
      );
      expect(nonMatchingTag.isEmpty, isTrue);
    });

    test('returns empty list when no decks match query', () {
      final results = ExploreScreen.filterDecks(
        allDecks: sampleDecks,
        query: 'NonExistentTopicXYZ',
        selectedTag: 'All',
      );
      expect(results, isEmpty);
    });
  });

  group('DeckCard Enhanced Action Button Widget Tests', () {
    testWidgets('renders actionLabel with custom actionColor even if onAction is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckCard(
              title: 'Sample Deck',
              subtitle: 'Author Name',
              totalCards: 10,
              tag: 'Tech',
              actionLabel: 'Imported',
              actionColor: Colors.green,
              onAction: null,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('IMPORTED'), findsOneWidget);
    });

    testWidgets('renders loading spinner when isActionLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckCard(
              title: 'Sample Deck',
              subtitle: 'Author Name',
              totalCards: 10,
              tag: 'Tech',
              actionLabel: 'Import',
              isActionLoading: true,
              onAction: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('fires onAction callback when tapped and not loading', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckCard(
              title: 'Sample Deck',
              subtitle: 'Author Name',
              totalCards: 10,
              tag: 'Tech',
              actionLabel: 'Import',
              isActionLoading: false,
              onAction: () => actionTapped = true,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('IMPORT'));
      expect(actionTapped, isTrue);
    });
  });
}
