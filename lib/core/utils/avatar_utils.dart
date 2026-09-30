import 'dart:convert';
import 'package:flutter/material.dart';

class PresetAvatar {
  final String id;
  final String name;
  final String imageUrl;

  const PresetAvatar({
    required this.id,
    required this.name,
    required this.imageUrl,
  });
}

class AvatarUtils {
  /// Safely resolves any photo URL into a Flutter [ImageProvider].
  /// Supports:
  /// 1. Base64 Data URIs (e.g. data:image/png;base64,iVBOR...)
  /// 2. Raw Base64 image strings
  /// 3. Remote HTTP/HTTPS network URLs
  /// Returns null if [photoUrl] is null, empty, or cannot be parsed.
  static ImageProvider? getAvatarImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.trim().isEmpty) {
      return null;
    }

    final trimmed = photoUrl.trim();

    // Base64 Data URI
    if (trimmed.startsWith('data:image') || trimmed.contains('base64,')) {
      try {
        final commaIndex = trimmed.indexOf(',');
        final base64String =
            commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
        final cleanBase64 = base64String.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('AvatarUtils: Failed to decode Base64 avatar: $e');
        return null;
      }
    }

    // Remote HTTP / HTTPS URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    return null;
  }

  /// Curated collection of high-resolution scholar and researcher avatars
  static const List<PresetAvatar> presetAvatars = [
    PresetAvatar(
      id: 'cyber_scholar',
      name: 'Cyber Scholar',
      imageUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'quantum_analyst',
      name: 'Quantum Analyst',
      imageUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'neural_sage',
      name: 'Neural Sage',
      imageUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'apex_thinker',
      name: 'Apex Thinker',
      imageUrl:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'cosmic_architect',
      name: 'Cosmic Architect',
      imageUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'codex_archivist',
      name: 'Codex Archivist',
      imageUrl:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'prism_strategist',
      name: 'Prism Strategist',
      imageUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=240&auto=format&fit=crop&q=80',
    ),
    PresetAvatar(
      id: 'atlas_scholar',
      name: 'Atlas Scholar',
      imageUrl:
          'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=240&auto=format&fit=crop&q=80',
    ),
  ];
}
