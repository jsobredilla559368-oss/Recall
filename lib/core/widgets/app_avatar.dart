import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/avatar_utils.dart';

class AppAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;
  final double borderWidth;
  final bool showEditBadge;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final Color? borderColor;
  final Color? glowColor;

  const AppAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 40,
    this.borderWidth = 2.5,
    this.showEditBadge = false,
    this.onTap,
    this.onEdit,
    this.borderColor,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    final effectiveBorderColor = borderColor ?? themePrimary.withValues(alpha: 0.6);
    final effectiveGlowColor = glowColor ?? themePrimary.withValues(alpha: 0.25);

    final imageProvider = AvatarUtils.getAvatarImageProvider(photoUrl);

    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'L';

    Widget avatarWidget = Container(
      padding: EdgeInsets.all(borderWidth > 0 ? 3.0 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: effectiveGlowColor,
            blurRadius: radius * 0.45,
            spreadRadius: 1.5,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surface,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? Text(
                initial,
                style: AppTypography.display.copyWith(
                  fontSize: radius * 0.8,
                  color: themePrimary,
                ),
              )
            : null,
      ),
    );

    if (onTap != null) {
      avatarWidget = InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatarWidget,
      );
    }

    if (!showEditBadge && onEdit == null) {
      return avatarWidget;
    }

    // Badge sizing proportional to avatar radius
    final badgeSize = (radius * 0.55).clamp(24.0, 36.0);
    final iconSize = (badgeSize * 0.52).clamp(12.0, 18.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarWidget,
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onEdit ?? onTap,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themePrimary,
                border: Border.all(
                  color: AppColors.background,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  LucideIcons.camera,
                  size: iconSize,
                  color: AppColors.background,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
