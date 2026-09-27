import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../../../core/theme/shop_ui.dart';

/// iOS 26's Liquid Glass, for the controls that float over content — the
/// tab bar, back buttons — and never for the content itself: a blur of
/// whatever scrolls underneath, a tint of the page's own tone, and a bright
/// rim so it reads as a pane rather than a hole.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = Radii.pill, this.shadow = true});

  final Widget child;
  final double radius;

  /// A soft drop shadow, for glass that sits well clear of the content.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final dark = ShopColors.of(context).isDark;
    final tint = dark ? const Color(0xFF232A28).withValues(alpha: 0.72) : const Color(0xFFFFFFFF).withValues(alpha: 0.72);
    final rim = dark ? const Color(0xFFFFFFFF).withValues(alpha: 0.10) : const Color(0xFFFFFFFF).withValues(alpha: 0.9);
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          if (shadow)
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: dark ? 0.3 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: shape,
              border: Border.all(color: rim, width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A round glass button holding one glyph, as iOS 26 puts in its bars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.label, required this.onTap, this.size = 40});

  final IconData icon;

  /// What VoiceOver reads; the button has no visible text.
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _Squish(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: GlassSurface(
            shadow: false,
            child: Center(child: Icon(icon, size: size * 0.5, color: ShopColors.of(context).ink)),
          ),
        ),
      ),
    );
  }
}

/// Back, as iOS 26 draws it: a chevron in a glass circle, with where it
/// goes back to said to VoiceOver rather than printed beside it.
class ShopBackButton extends StatelessWidget {
  const ShopBackButton({super.key, this.to});

  /// The screen it returns to, for VoiceOver ("Back to Stock").
  final String? to;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        label: to == null ? 'Back' : 'Back to $to',
        onTap: () => Navigator.of(context).maybePop(),
      );
}

/// A pushed screen's bar: the title in the middle, a glass back button, and
/// no hairline — the bar is clear until content scrolls under it, then
/// blurs it, the way iOS 26 marks where controls and content meet.
CupertinoNavigationBar shopNavBar({required String title, String? backTo}) => CupertinoNavigationBar(
      automaticallyImplyLeading: false,
      padding: const EdgeInsetsDirectional.only(start: Space.sm + Space.xs, end: Space.sm + Space.xs),
      leading: Align(widthFactor: 1, child: ShopBackButton(to: backTo)),
      middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      border: null,
    );

/// A press that shrinks a touch, like glass controls do under a finger.
class _Squish extends StatefulWidget {
  const _Squish({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Squish> createState() => _SquishState();
}

class _SquishState extends State<_Squish> {
  bool _down = false;

  void _set(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: widget.child,
        ),
      );
}
