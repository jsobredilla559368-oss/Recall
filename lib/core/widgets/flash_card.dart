import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dart:math';

class FlashCard extends StatefulWidget {
  final String frontText;
  final String backText;
  final bool forceReveal;

  const FlashCard({
    super.key,
    required this.frontText,
    required this.backText,
    this.forceReveal = false,
  });

  @override
  State<FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<FlashCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  void didUpdateWidget(FlashCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceReveal && !oldWidget.forceReveal && _isFront) {
      _flipCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBackVisible = angle > pi / 2;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
              ),
              child: isBackVisible
                  ? Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: _buildSide('ANSWER', widget.backText),
                    )
                  : _buildSide('QUESTION', widget.frontText),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSide(String label, String content) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  content,
                  style: content.length > 90
                      ? AppTypography.body.copyWith(fontSize: 18, height: 1.5)
                      : (content.length > 45
                          ? AppTypography.h2
                          : AppTypography.h1),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Tap to reveal',
          style: AppTypography.caption.copyWith(color: AppColors.accent),
        ),
      ],
    );
  }
}
