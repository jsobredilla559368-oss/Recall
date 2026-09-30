import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocumentExtractResult {
  final String fileName;
  final int fileSizeBytes;
  final String extractedText;
  final int wordCount;
  final int charCount;
  final String? warning;

  DocumentExtractResult({
    required this.fileName,
    required this.fileSizeBytes,
    required this.extractedText,
    required this.wordCount,
    required this.charCount,
    this.warning,
  });

  bool get hasText => extractedText.trim().isNotEmpty;

  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

class DocumentService {
  /// Picks a PDF or text file using the native file picker and extracts its text.
  static Future<DocumentExtractResult?> pickAndExtractDocument() async {
    try {
      final platformFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
      );

      if (platformFile == null) {
        return null; // User cancelled
      }

      final fileName = platformFile.name;
      final fileSizeBytes =
          platformFile.lengthSync() ?? await platformFile.length();
      final bytes = await platformFile.readAsBytes();

      if (bytes.isEmpty) {
        return DocumentExtractResult(
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          extractedText: '',
          wordCount: 0,
          charCount: 0,
          warning: 'The selected file is empty. Please choose another document.',
        );
      }

      return extractTextFromBytes(bytes, fileName, fileSizeBytes);
    } catch (e) {
      debugPrint('[DocumentService] Error picking/extracting document: $e');
      rethrow;
    }
  }

  /// Extracts text from in-memory byte buffer based on file extension.
  static DocumentExtractResult extractTextFromBytes(
    Uint8List bytes,
    String fileName, [
    int? sizeBytes,
  ]) {
    final lowerName = fileName.toLowerCase();
    String rawText = '';
    String? warning;

    try {
      if (lowerName.endsWith('.pdf')) {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        rawText = extractor.extractText();
        document.dispose();
      } else {
        // Fallback to text / markdown UTF-8 decoding
        rawText = utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      debugPrint('[DocumentService] Failed to extract text from $fileName: $e');
      warning = 'Failed to extract text: ${e.toString()}';
    }

    final cleanedText = rawText.trim();
    final words = cleanedText.isEmpty
        ? 0
        : cleanedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = cleanedText.length;

    if (cleanedText.isEmpty && warning == null) {
      warning =
          'No readable text detected in this document. Scanned image PDFs without selectable text are not supported.';
    }

    return DocumentExtractResult(
      fileName: fileName,
      fileSizeBytes: sizeBytes ?? bytes.length,
      extractedText: cleanedText,
      wordCount: words,
      charCount: chars,
      warning: warning,
    );
  }
}
