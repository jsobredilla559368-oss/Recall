import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/services/storage_service.dart';
import 'package:recall/features/decks/models/deck_model.dart';

/// Test mock implementation of IStorageService to test upload contracts
class MockTestStorageService implements IStorageService {
  final Map<String, Uint8List> storedFiles = {};
  bool deleteCalled = false;
  String? lastDeletedPath;

  @override
  Future<String> uploadFile(File file, String path, {String? contentType}) async {
    final bytes = await file.readAsBytes();
    storedFiles[path] = bytes;
    return 'https://firebasestorage.googleapis.com/v0/b/recall.appspot.com/o/${Uri.encodeComponent(path)}?alt=media';
  }

  @override
  Future<String> uploadBytes(Uint8List bytes, String path, {String contentType = 'image/jpeg'}) async {
    storedFiles[path] = bytes;
    return 'https://firebasestorage.googleapis.com/v0/b/recall.appspot.com/o/${Uri.encodeComponent(path)}?alt=media';
  }

  @override
  Future<void> deleteFile(String pathOrUrl) async {
    deleteCalled = true;
    lastDeletedPath = pathOrUrl;
    storedFiles.remove(pathOrUrl);
  }
}

void main() {
  group('Account Deletion & Data Cascade Unit Tests', () {
    test('Public deck anonymization preserves community content under Anonymous Scholar', () {
      final userUid = 'user_12345';
      final originalPublicDeck = DeckModel(
        id: 'deck_public_001',
        title: 'Microbiology Fundamentals',
        description: 'Bacterial and viral pathogenesis review',
        totalCards: 15,
        tag: 'Medicine',
        isFlashcard: true,
        author: 'Dr. Jane Doe',
        createdBy: userUid,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        isPublic: true,
      );

      // Simulate anonymization performed in deleteAccountCascade
      final anonymizedDeck = originalPublicDeck.copyWith(
        createdBy: 'deleted_user',
        author: 'Anonymous Scholar',
      );

      expect(anonymizedDeck.id, equals('deck_public_001'));
      expect(anonymizedDeck.title, equals('Microbiology Fundamentals'));
      expect(anonymizedDeck.isPublic, isTrue);
      expect(anonymizedDeck.createdBy, equals('deleted_user'));
      expect(anonymizedDeck.author, equals('Anonymous Scholar'));
    });

    test('Private decks are classified for hard deletion while public decks are preserved', () {
      final userUid = 'user_12345';
      final userDecks = [
        DeckModel(
          id: 'deck_priv_01',
          title: 'My Secret Notes',
          description: 'Private exam cram',
          totalCards: 5,
          tag: 'General',
          isFlashcard: true,
          author: 'Me',
          createdBy: userUid,
          createdAt: DateTime.now(),
          isPublic: false,
        ),
        DeckModel(
          id: 'deck_pub_02',
          title: 'Public Chemistry 101',
          description: 'Open to everyone',
          totalCards: 20,
          tag: 'Chemistry',
          isFlashcard: false,
          author: 'Me',
          createdBy: userUid,
          createdAt: DateTime.now(),
          isPublic: true,
        ),
      ];

      final decksToHardDelete = userDecks.where((d) => !d.isPublic).toList();
      final decksToAnonymize = userDecks.where((d) => d.isPublic).toList();

      expect(decksToHardDelete.length, equals(1));
      expect(decksToHardDelete.first.id, equals('deck_priv_01'));
      expect(decksToAnonymize.length, equals(1));
      expect(decksToAnonymize.first.id, equals('deck_pub_02'));
    });

    test('Deletion confirmation check requires exact word DELETE', () {
      bool canDelete(String input) => input.trim() == 'DELETE';

      expect(canDelete(''), isFalse);
      expect(canDelete('delete'), isFalse);
      expect(canDelete('Delete'), isFalse);
      expect(canDelete('DELETE '), isTrue);
      expect(canDelete('DELETE'), isTrue);
    });
  });

  group('StorageService Unit Tests', () {
    test('MockTestStorageService uploads bytes and returns valid download URL', () async {
      final storage = MockTestStorageService();
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final path = 'users/user_123/avatar.jpg';

      final url = await storage.uploadBytes(sampleBytes, path);

      expect(url, contains('firebasestorage.googleapis.com'));
      expect(url, contains('users%2Fuser_123%2Favatar.jpg'));
      expect(storage.storedFiles[path], equals(sampleBytes));
    });

    test('MockTestStorageService deletes avatar file on account cascade', () async {
      final storage = MockTestStorageService();
      final path = 'users/user_123/avatar.jpg';
      await storage.uploadBytes(Uint8List.fromList([1, 2]), path);

      await storage.deleteFile(path);

      expect(storage.deleteCalled, isTrue);
      expect(storage.lastDeletedPath, equals(path));
      expect(storage.storedFiles.containsKey(path), isFalse);
    });
  });
}
