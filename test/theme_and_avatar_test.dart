import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/services/theme_service.dart';
import 'package:recall/core/theme/app_colors.dart';
import 'package:recall/core/utils/avatar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarUtils', () {
    test('returns null for null, empty, or whitespace photoUrl', () {
      expect(AvatarUtils.getAvatarImageProvider(null), isNull);
      expect(AvatarUtils.getAvatarImageProvider(''), isNull);
      expect(AvatarUtils.getAvatarImageProvider('   \n  '), isNull);
    });

    test('returns NetworkImage for valid HTTP/HTTPS URLs', () {
      final provider =
          AvatarUtils.getAvatarImageProvider('https://example.com/scholar.jpg');
      expect(provider, isA<NetworkImage>());
      expect((provider as NetworkImage).url, 'https://example.com/scholar.jpg');

      final httpProvider =
          AvatarUtils.getAvatarImageProvider('http://example.com/user.png');
      expect(httpProvider, isA<NetworkImage>());
    });

    test('returns MemoryImage for valid Base64 data URIs', () {
      // 1x1 transparent PNG encoded in Base64
      const validBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      const dataUri = 'data:image/png;base64,$validBase64';

      final provider = AvatarUtils.getAvatarImageProvider(dataUri);
      expect(provider, isA<MemoryImage>());
      final memoryImage = provider as MemoryImage;
      expect(memoryImage.bytes, base64Decode(validBase64));
    });

    test('handles malformed Base64 data gracefully without throwing', () {
      const invalidDataUri = 'data:image/png;base64,!!!NotValidBase64!!!';
      expect(AvatarUtils.getAvatarImageProvider(invalidDataUri), isNull);
    });

    test('has curated preset avatars with valid URLs and titles', () {
      expect(AvatarUtils.presetAvatars.length, 8);
      for (final preset in AvatarUtils.presetAvatars) {
        expect(preset.id.isNotEmpty, isTrue);
        expect(preset.name.isNotEmpty, isTrue);
        expect(preset.imageUrl.startsWith('https://'), isTrue);
      }
    });
  });

  group('ThemeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with default hue and Electric Teal colors', () {
      final service = ThemeService();
      expect(service.hue, ThemeService.defaultHue);
      expect(service.primaryColor, isNotNull);
      expect(service.secondaryColor, isNotNull);
      expect(service.primaryGradient.colors.length, 2);
    });

    test('setHue updates hue smoothly and recalculates gradient', () {
      final service = ThemeService();
      service.setHue(270.0); // Violet
      expect(service.hue, 270.0);
      expect(service.selectedPreset, isNull);

      final theme = service.themeData;
      expect(theme.colorScheme.primary, service.primaryColor);
      expect(theme.colorScheme.secondary, service.secondaryColor);
    });

    test('setPreset applies preset colors and updates hue', () {
      final service = ThemeService();
      final sunsetPreset = ThemeService.presets.firstWhere((p) => p.id == 'amber');
      service.setPreset(sunsetPreset);

      expect(service.selectedPreset?.id, 'amber');
      expect(service.primaryColor, sunsetPreset.primaryColor);
      expect(service.secondaryColor, sunsetPreset.secondaryColor);
      expect(service.hue, sunsetPreset.hue);
    });

    test('resetToDefault restores Electric Teal default', () {
      final service = ThemeService();
      service.setHue(45.0);
      expect(service.hue, 45.0);

      service.resetToDefault();
      expect(service.hue, ThemeService.defaultHue);
      expect(service.selectedPreset?.id, 'teal');
    });

    test('clamps hue between 0.0 and 360.0', () {
      final service = ThemeService();
      service.setHue(-15.0);
      expect(service.hue, 0.0);

      service.setHue(400.0);
      expect(service.hue, 360.0);
    });

    test('AppColors getters dynamically track ThemeService.instance', () {
      final instance = ThemeService.instance;
      instance.resetToDefault();

      // Default Electric Teal
      expect(AppColors.accent, instance.primaryColor);
      expect(AppColors.secondaryAccent, instance.secondaryColor);
      expect(AppColors.gradient, instance.primaryGradient);
      expect(AppColors.auraGradient, instance.cardAuraGradient);

      // Change hue to Purple/Violet (~270°)
      instance.setHue(270.0);
      expect(AppColors.accent, instance.primaryColor);
      expect(AppColors.secondaryAccent, instance.secondaryColor);
      expect(AppColors.accent, isNot(AppColors.defaultAccent));

      // Apply Sunset Amber Preset
      final amberPreset = ThemeService.presets.firstWhere((p) => p.id == 'amber');
      instance.setPreset(amberPreset);
      expect(AppColors.accent, amberPreset.primaryColor);
      expect(AppColors.secondaryAccent, amberPreset.secondaryColor);

      // Reset
      instance.resetToDefault();
      expect(AppColors.accent, instance.primaryColor);
    });
  });
}
