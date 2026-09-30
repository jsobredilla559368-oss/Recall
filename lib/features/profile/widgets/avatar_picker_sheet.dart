import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/avatar_utils.dart';
import '../../../core/widgets/app_avatar.dart';

class AvatarPickerSheet extends StatefulWidget {
  final String uid;
  final String displayName;
  final String? currentPhotoUrl;

  const AvatarPickerSheet({
    super.key,
    required this.uid,
    required this.displayName,
    this.currentPhotoUrl,
  });

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  String? _selectedPhotoUrl;
  bool _isSaving = false;
  bool _isPicking = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPhotoUrl = widget.currentPhotoUrl;
    if (widget.currentPhotoUrl != null &&
        !widget.currentPhotoUrl!.startsWith('data:')) {
      _urlController.text = widget.currentPhotoUrl!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromDevice() async {
    setState(() => _isPicking = true);
    try {
      final platformFile = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (platformFile == null) {
        setState(() => _isPicking = false);
        return;
      }

      final bytes = await platformFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected image file was empty.')),
          );
        }
        setState(() => _isPicking = false);
        return;
      }

      // 5MB safety limit matching storage.rules
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large. Please select a photo under 5MB.'),
            ),
          );
        }
        setState(() => _isPicking = false);
        return;
      }

      final fileName = platformFile.name.toLowerCase();
      final mime = fileName.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final base64String = base64Encode(bytes);
      final dataUri = 'data:$mime;base64,$base64String';

      setState(() {
        _selectedPhotoUrl = dataUri;
        _isPicking = false;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
      setState(() => _isPicking = false);
    }
  }

  Future<void> _saveAvatar() async {
    setState(() => _isSaving = true);
    try {
      String? finalPhotoUrl = _selectedPhotoUrl;

      // If a local image was picked (data URI), upload to real Firebase Cloud Storage!
      if (finalPhotoUrl != null && finalPhotoUrl.startsWith('data:')) {
        try {
          final storage = context.read<StorageService>();
          final commaIndex = finalPhotoUrl.indexOf(',');
          if (commaIndex != -1) {
            final header = finalPhotoUrl.substring(0, commaIndex);
            final base64Data = finalPhotoUrl.substring(commaIndex + 1);
            final bytes = base64Decode(base64Data);
            final mime = header.contains('png') ? 'image/png' : 'image/jpeg';
            final ext = mime == 'image/png' ? 'png' : 'jpg';

            finalPhotoUrl = await storage.uploadBytes(
              bytes,
              'users/${widget.uid}/avatar.$ext',
              contentType: mime,
            );
          }
        } catch (storageErr) {
          debugPrint('Notice: Cloud storage upload failed ($storageErr), preserving data URI.');
        }
      }

      if (!mounted) return;
      await context
          .read<UserService>()
          .updatePhotoUrl(widget.uid, finalPhotoUrl);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              'Profile picture updated successfully!',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update avatar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePrimary = Theme.of(context).colorScheme.primary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text('Profile Picture', style: AppTypography.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Upload a photo from your device or choose a curated scholar preset.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 24),

                  // Live Preview
                  Center(
                    child: Column(
                      children: [
                        AppAvatar(
                          photoUrl: _selectedPhotoUrl,
                          displayName: widget.displayName,
                          radius: 50,
                          borderWidth: 3,
                          glowColor: themePrimary.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedPhotoUrl == null
                              ? 'Current: Monogram Initial'
                              : (_selectedPhotoUrl!.startsWith('data:')
                                  ? 'Custom Device Photo'
                                  : 'Selected Avatar'),
                          style: AppTypography.caption.copyWith(
                            color: themePrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Upload from Device Card
                  InkWell(
                    onTap: _isPicking ? null : _pickImageFromDevice,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themePrimary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: themePrimary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: _isPicking
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: themePrimary,
                                    ),
                                  )
                                : Icon(
                                    LucideIcons.image,
                                    color: themePrimary,
                                    size: 20,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose from Device',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Pick PNG, JPG, or WEBP photo from gallery',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(LucideIcons.chevronRight,
                              color: AppColors.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scholar Presets Header
                  Text(
                    'SCHOLAR PRESETS',
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Presets Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: AvatarUtils.presetAvatars.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      final preset = AvatarUtils.presetAvatars[index];
                      final isSelected = _selectedPhotoUrl == preset.imageUrl;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPhotoUrl = preset.imageUrl;
                            _urlController.text = preset.imageUrl;
                          });
                        },
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? themePrimary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: themePrimary.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.background,
                                backgroundImage:
                                    NetworkImage(preset.imageUrl),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preset.name.split(' ').first,
                              style: AppTypography.caption.copyWith(
                                fontSize: 10,
                                color: isSelected
                                    ? themePrimary
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Direct Web URL Accordion / Field
                  Text(
                    'WEB IMAGE LINK',
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: AppTypography.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'https://example.com/avatar.jpg',
                            hintStyle: AppTypography.caption,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.textMuted.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: themePrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.background,
                          foregroundColor: themePrimary,
                          side: BorderSide(
                              color: themePrimary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () {
                          final text = _urlController.text.trim();
                          if (text.isNotEmpty) {
                            setState(() => _selectedPhotoUrl = text);
                          }
                        },
                        child: const Text('Preview'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Remove Current Photo
                  if (_selectedPhotoUrl != null)
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(LucideIcons.trash2,
                            size: 16, color: AppColors.error),
                        label: const Text(
                          'Reset to Monogram Initial',
                          style: TextStyle(color: AppColors.error),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPhotoUrl = null;
                            _urlController.clear();
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.textMuted.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themePrimary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveAvatar,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Text(
                            'Save Profile Picture',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
