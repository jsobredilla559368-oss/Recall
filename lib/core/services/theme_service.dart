import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GradientPreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final double hue;

  const GradientPreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.hue,
  });

  LinearGradient get gradient => LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class ThemeService extends ChangeNotifier {
  static const String _prefHueKey = 'recall_theme_hue';
  static const String _prefPresetKey = 'recall_theme_preset_id';

  static const double defaultHue = 174.0; // Electric Teal
  static const Color defaultPrimary = AppColors.defaultAccent; // #00E5C8
  static const Color defaultSecondary = Color(0xFF00A3FF); // Bright cyan/blue

  static final List<GradientPreset> presets = [
    const GradientPreset(
      id: 'teal',
      name: 'Electric Teal',
      primaryColor: Color(0xFF00E5C8),
      secondaryColor: Color(0xFF00A3FF),
      hue: 174.0,
    ),
    const GradientPreset(
      id: 'violet',
      name: 'Cosmic Violet',
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFEC4899),
      hue: 270.0,
    ),
    const GradientPreset(
      id: 'amber',
      name: 'Sunset Ember',
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFEF4444),
      hue: 35.0,
    ),
    const GradientPreset(
      id: 'emerald',
      name: 'Emerald Pulse',
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF06B6D4),
      hue: 155.0,
    ),
    const GradientPreset(
      id: 'rose',
      name: 'Cyber Rose',
      primaryColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFF8B5CF6),
      hue: 335.0,
    ),
    const GradientPreset(
      id: 'midnight',
      name: 'Deep Midnight',
      primaryColor: Color(0xFF3B82F6),
      secondaryColor: Color(0xFF1D4ED8),
      hue: 220.0,
    ),
  ];

  double _hue = defaultHue;
  GradientPreset? _selectedPreset;
  SharedPreferences? _prefs;

  static final ThemeService instance = ThemeService._internal();
  factory ThemeService() => instance;

  ThemeService._internal() {
    _initPrefs();
  }

  double get hue => _hue;
  GradientPreset? get selectedPreset => _selectedPreset;

  Color get primaryColor {
    if (_selectedPreset != null) {
      return _selectedPreset!.primaryColor;
    }
    return HSLColor.fromAHSL(1.0, _hue, 1.0, 0.48).toColor();
  }

  Color get secondaryColor {
    if (_selectedPreset != null) {
      return _selectedPreset!.secondaryColor;
    }
    return HSLColor.fromAHSL(1.0, (_hue + 38.0) % 360.0, 0.95, 0.55).toColor();
  }

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get cardAuraGradient => LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.18),
          secondaryColor.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  ThemeData get themeData {
    final primary = primaryColor;
    final secondary = secondaryColor;

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.background,
        onSecondary: AppColors.background,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        headlineLarge: AppTypography.h1,
        titleLarge: AppTypography.h2,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodyMedium,
        labelSmall: AppTypography.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.h2,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle: AppTypography.caption.copyWith(
          color: primary,
          fontSize: 10,
        ),
        unselectedLabelStyle: AppTypography.caption.copyWith(fontSize: 10),
      ),
    );
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedPresetId = _prefs?.getString(_prefPresetKey);
      if (savedPresetId != null) {
        final match = presets.where((p) => p.id == savedPresetId);
        if (match.isNotEmpty) {
          _selectedPreset = match.first;
          _hue = _selectedPreset!.hue;
          notifyListeners();
          return;
        }
      }

      final savedHue = _prefs?.getDouble(_prefHueKey);
      if (savedHue != null) {
        _hue = savedHue.clamp(0.0, 360.0);
        _selectedPreset = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error initializing theme preferences: $e");
    }
  }

  void setHue(double hue) {
    _hue = hue.clamp(0.0, 360.0);
    _selectedPreset = null;
    notifyListeners();
    _prefs?.setDouble(_prefHueKey, _hue);
    _prefs?.remove(_prefPresetKey);
  }

  void setPreset(GradientPreset preset) {
    _selectedPreset = preset;
    _hue = preset.hue;
    notifyListeners();
    _prefs?.setString(_prefPresetKey, preset.id);
    _prefs?.setDouble(_prefHueKey, preset.hue);
  }

  void resetToDefault() {
    _selectedPreset = presets.first; // Electric Teal
    _hue = defaultHue;
    notifyListeners();
    _prefs?.remove(_prefHueKey);
    _prefs?.remove(_prefPresetKey);
  }
}
