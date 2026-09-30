import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/services/document_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('DocumentService Extraction Tests', () {
    test('Extracts text correctly from text (.txt) file bytes', () {
      const sampleText = 'Photosynthesis is the process by which green plants use sunlight to synthesize nutrients.';
      final bytes = Uint8List.fromList(utf8.encode(sampleText));

      final result = DocumentService.extractTextFromBytes(bytes, 'biology_notes.txt');

      expect(result.fileName, 'biology_notes.txt');
      expect(result.extractedText, sampleText);
      expect(result.wordCount, 13);
      expect(result.hasText, true);
      expect(result.warning, isNull);
    });

    test('Extracts text correctly from generated PDF document bytes', () {
      // Create a test PDF in-memory with Syncfusion
      final PdfDocument document = PdfDocument();
      final page = document.pages.add();
      page.graphics.drawString(
        'Machine learning algorithms build a mathematical model based on training data.',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );

      final List<int> pdfBytes = document.saveSync();
      document.dispose();

      final result = DocumentService.extractTextFromBytes(
        Uint8List.fromList(pdfBytes),
        'ml_lecture.pdf',
      );

      expect(result.fileName, 'ml_lecture.pdf');
      expect(result.hasText, true);
      expect(result.extractedText, contains('Machine learning algorithms'));
      expect(result.wordCount, greaterThanOrEqualTo(10));
      expect(result.formattedFileSize, contains('B'));
    });

    test('Properly formats file sizes in DocumentExtractResult', () {
      final small = DocumentExtractResult(
        fileName: 'a.txt',
        fileSizeBytes: 500,
        extractedText: 'hello',
        wordCount: 1,
        charCount: 5,
      );
      expect(small.formattedFileSize, '500 B');

      final medium = DocumentExtractResult(
        fileName: 'b.pdf',
        fileSizeBytes: 1024 * 350,
        extractedText: 'sample',
        wordCount: 1,
        charCount: 6,
      );
      expect(medium.formattedFileSize, '350.0 KB');

      final large = DocumentExtractResult(
        fileName: 'c.pdf',
        fileSizeBytes: (1024 * 1024 * 2.5).toInt(),
        extractedText: 'book',
        wordCount: 1,
        charCount: 4,
      );
      expect(large.formattedFileSize, '2.50 MB');
    });
  });
}
