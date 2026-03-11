import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated AI Summary card with shimmer border, typewriter text animation,
/// and smooth state transitions.
class AiSummaryCard extends StatefulWidget {
  final String? summary;
  final bool isLoading;
  final VoidCallback onGenerate;
  final void Function(String text) onCopy;
  final String? emptyStateText;
  final String? generateButtonLabel;

  const AiSummaryCard({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.onGenerate,
    required this.onCopy,
    this.emptyStateText,
    this.generateButtonLabel,
  });

  @override
  State<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<AiSummaryCard>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _iconPulseController;
  late AnimationController _buttonFadeController;

  // Typewriter state
  Timer? _typewriterTimer;
  int _visibleCharCount = 0;
  bool _isTyping = false;
  String? _lastSummary;

  // Animated dots for loading
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _buttonFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (widget.summary != null) {
      _visibleCharCount = widget.summary!.length;
      _lastSummary = widget.summary;
      _buttonFadeController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AiSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // New summary arrived — start typewriter
    if (widget.summary != null &&
        widget.summary != _lastSummary &&
        oldWidget.summary != widget.summary) {
      _lastSummary = widget.summary;
      _startTypewriter(widget.summary!);
    }
  }

  void _startTypewriter(String text) {
    _typewriterTimer?.cancel();
    _visibleCharCount = 0;
    _isTyping = true;
    _buttonFadeController.value = 0.0;

    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: 18),
      (timer) {
        if (_visibleCharCount >= text.length) {
          timer.cancel();
          setState(() => _isTyping = false);
          _buttonFadeController.forward();
          return;
        }
        setState(() => _visibleCharCount++);
      },
    );
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _shimmerController.dispose();
    _iconPulseController.dispose();
    _buttonFadeController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShimmerBorderPainter(
            progress: _shimmerController.value,
            primaryColor: colorScheme.primary,
            secondaryColor: colorScheme.tertiary,
            isLoading: widget.isLoading,
          ),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.all(2), // space for the painted border
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, colorScheme),
            const SizedBox(height: 16),
            _buildBody(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Pulsing AI icon
        AnimatedBuilder(
          animation: _iconPulseController,
          builder: (context, child) {
            final scale = 1.0 + _iconPulseController.value * 0.1;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.15),
                  colorScheme.tertiary.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.bolt, size: 12, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Powered by OpenAI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final glowOpacity =
            0.15 + 0.15 * math.sin(_shimmerController.value * math.pi * 2);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: glowOpacity),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FilledButton.icon(
        onPressed: widget.onGenerate,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(widget.generateButtonLabel ?? 'Generate'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (widget.isLoading) {
      return _buildLoadingState(theme, colorScheme);
    }
    if (widget.summary != null) {
      return _buildSummaryState(theme, colorScheme);
    }
    return _buildEmptyState(theme, colorScheme);
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _dotsController,
              builder: (context, _) {
                final dotCount = (_dotsController.value * 4).floor() % 4;
                final dots = '.' * dotCount;
                return Text(
                  'Analyzing department data$dots',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryState(ThemeData theme, ColorScheme colorScheme) {
    final fullText = widget.summary!;
    final displayedText = fullText.substring(
      0,
      _visibleCharCount.clamp(0, fullText.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary text with cursor
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.7,
              color: colorScheme.onSurface,
            ),
            children: [
              TextSpan(text: displayedText),
              if (_isTyping)
                TextSpan(
                  text: '│',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action buttons — fade in after typewriter completes
        FadeTransition(
          opacity: _buttonFadeController,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionChip(
                icon: Icons.refresh_rounded,
                label: 'Regenerate',
                color: colorScheme.secondary,
                onTap: widget.onGenerate,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: colorScheme.secondary,
                onTap: () => widget.onCopy(fullText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.emptyStateText ??
              'Get a quick, AI-generated overview of this department\'s key functions and services.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _buildGenerateButton(colorScheme)),
      ],
    );
  }
}

// ── Shimmer Border Painter ──────────────────────────────────────────

class _ShimmerBorderPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLoading;

  _ShimmerBorderPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isLoading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Use a smooth sine-based easing so the rotation never "jumps"
    final smoothProgress =
        (math.sin(progress * 2 * math.pi - math.pi / 2) + 1) / 2;
    final sweepAngle = smoothProgress * 2 * math.pi;

    final hi = isLoading ? 0.8 : 0.5;
    final mid = isLoading ? 0.5 : 0.25;
    final lo = isLoading ? 0.15 : 0.05;

    // The first and last color/stop match so the gradient wraps seamlessly
    final gradient = SweepGradient(
      transform: GradientRotation(sweepAngle),
      colors: [
        primaryColor.withValues(alpha: lo),
        secondaryColor.withValues(alpha: mid),
        primaryColor.withValues(alpha: hi),
        secondaryColor.withValues(alpha: mid),
        primaryColor.withValues(alpha: lo),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLoading ? 2.5 : 2.0;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isLoading != isLoading;
  }
}

// ── Action Chip Button ──────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
