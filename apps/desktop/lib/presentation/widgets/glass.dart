import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// iOS 26's Liquid Glass, for the control layer that floats over content —
/// the sidebar, floating buttons — and never for the content itself. As
/// Apple describes the material: a blur of whatever is underneath with its
/// color lifted (what separates it from flat frosted panels), a thin tint, a
/// rim that catches the light at the top, and a soft shadow kept outside
/// the shape. With high contrast on it turns nearly opaque, as the system's
/// does.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({super.key, required this.child, this.shape = const StadiumBorder(), this.shadow = true});

  final Widget child;

  /// StadiumBorder for capsules, CircleBorder for round buttons, a rounded
  /// superellipse for panels.
  final ShapeBorder shape;

  /// A soft drop shadow, for glass that floats clear of the content.
  final bool shadow;

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0,
      i * r, i * g, i * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final base = dark ? const Color(0xFF2A2A2D) : const Color(0xFFFFFFFF);
    final alpha = solid ? 0.96 : (dark ? 0.62 : 0.72);

    return CustomPaint(
      painter: shadow ? _OuterShadow(shape: shape, dark: dark) : null,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ColorFilter.matrix(_saturation(1.6)),
            inner: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          ),
          child: CustomPaint(
            foregroundPainter: _Rim(shape: shape, dark: dark),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                color: base.withValues(alpha: alpha),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bright edge that makes glass read as a pane, brightest at the top
/// where light would catch it.
class _Rim extends CustomPainter {
  _Rim({required this.shape, required this.dark});
  final ShapeBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const white = Color(0xFFFFFFFF);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          white.withValues(alpha: dark ? 0.22 : 0.95),
          white.withValues(alpha: dark ? 0.05 : 0.4),
        ],
      ).createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(_Rim old) => old.dark != dark || old.shape != shape;
}

/// A shadow painted only outside the shape, so it neither darkens the
/// glass nor gets pulled into the backdrop blur.
class _OuterShadow extends CustomPainter {
  _OuterShadow({required this.shape, required this.dark});
  final ShapeBorder shape;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.getOuterPath(rect);
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(60)), outline));
    canvas.drawPath(
      outline.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: dark ? 0.4 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) => old.dark != dark || old.shape != shape;
}
