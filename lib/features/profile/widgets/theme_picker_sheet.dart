import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ThemePickerSheet extends StatefulWidget {
  const ThemePickerSheet({super.key});

  @override
  State<ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<ThemePickerSheet> {
  // Rainbow spectrum colors for the slider track
  static final List<Color> _spectrumColors = [
    const Color(0xFFFF0000), // 0° Red
    const Color(0xFFFFFF00), // 60° Yellow
    const Color(0xFF00FF00), // 120° Green
    const Color(0xFF00FFFF), // 180° Cyan
    const Color(0xFF0000FF), // 240° Blue
    const Color(0xFFFF00FF), // 300° Magenta
    const Color(0xFFFF0000), // 360° Red
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final themeService = ThemeService.instance;
        final primary = themeService.primaryColor;
        final gradient = themeService.primaryGradient;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.textMuted.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Theme & Gradient Colors',
                                  style: AppTypography.h2),
                              const SizedBox(height: 2),
                              Text(
                                'Personalize Recall with custom spectrum gradients',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: gradient,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Live Interactive Preview Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.15),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'LIVE PREVIEW',
                                  style: AppTypography.caption.copyWith(
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                                // Mini Streak Pill with Gradient
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: gradient,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.flame,
                                          size: 13,
                                          color: AppColors.background),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '14-Day Streak',
                                        style: TextStyle(
                                          color: AppColors.background,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Mastery Flashcard Deck',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Review 25 critical terms using adaptive spaced repetition.',
                              style: AppTypography.caption,
                            ),
                            const SizedBox(height: 16),
                            // Mini Gradient CTA Button
                            Container(
                              width: double.infinity,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: gradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(LucideIcons.play,
                                        size: 15,
                                        color: AppColors.background),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Start Practice Session',
                                      style: TextStyle(
                                        color: AppColors.background,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Color Spectrum Slider Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'COLOR SPECTRUM SLIDER',
                            style: AppTypography.caption.copyWith(
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            'Hue: ${themeService.hue.round()}°',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Custom Rainbow Gradient Slider Track
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final trackWidth = constraints.maxWidth;
                          final thumbX =
                              (themeService.hue / 360.0) * trackWidth;

                          return GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              final localX = details.localPosition.dx;
                              final newHue =
                                  (localX / trackWidth * 360.0).clamp(0.0, 360.0);
                              themeService.setHue(newHue);
                            },
                            onTapDown: (details) {
                              final localX = details.localPosition.dx;
                              final newHue =
                                  (localX / trackWidth * 360.0).clamp(0.0, 360.0);
                              themeService.setHue(newHue);
                            },
                            child: SizedBox(
                              height: 38,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Rainbow Track
                                  Container(
                                    height: 18,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      gradient: LinearGradient(
                                        colors: _spectrumColors,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Glowing Slider Thumb
                                  Positioned(
                                    left: (thumbX - 14).clamp(0.0, trackWidth - 28),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primary,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withValues(alpha: 0.8),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),

                      // Curated Gradient Presets
                      Text(
                        'CURATED GRADIENT PRESETS',
                        style: AppTypography.caption.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: ThemeService.presets.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.5,
                        ),
                        itemBuilder: (context, index) {
                          final preset = ThemeService.presets[index];
                          final isSelected =
                              themeService.selectedPreset?.id == preset.id;

                          return InkWell(
                            onTap: () => themeService.setPreset(preset),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? preset.primaryColor.withValues(alpha: 0.15)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? preset.primaryColor
                                      : AppColors.textMuted.withValues(alpha: 0.15),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: preset.gradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: preset.primaryColor
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      preset.name,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? preset.primaryColor
                                            : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Reset to Default Action
                      Center(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                          ),
                          icon: const Icon(LucideIcons.rotateCcw, size: 15),
                          label: const Text('Reset to Electric Teal (Default)'),
                          onPressed: () => themeService.resetToDefault(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Done Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.textMuted.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
