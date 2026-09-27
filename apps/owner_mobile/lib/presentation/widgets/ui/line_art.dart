import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/shop_ui.dart';

/// The shop's one-line drawings (assets/animations), each cropped to its
/// ink with the line weight evened out. Free from LottieFiles under the
/// Lottie Simple License: the tee, dress and bag by SM, the paper by
/// Anayatul Islam Nayeem.
enum LineArtDrawing {
  tee('tee', 1110 / 694),
  dress('dress', 1126 / 664),
  bag('bag', 1342 / 608),
  paper('paper', 204 / 258);

  const LineArtDrawing(this._name, this.aspectRatio);
  final String _name;

  /// Width over height, so the space is held before the file loads.
  final double aspectRatio;

  String get asset => 'assets/animations/$_name.json';
}

/// A one-line drawing that draws itself once and stays drawn, in the
/// shop's ink (and sage where the drawing has a fill). With Reduce Motion
/// on it appears already drawn.
class LineArt extends StatefulWidget {
  const LineArt(this.drawing, {super.key, required this.height});

  final LineArtDrawing drawing;
  final double height;

  @override
  State<LineArt> createState() => _LineArtState();
}

class _LineArtState extends State<LineArt> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    return ExcludeSemantics(
      child: Lottie.asset(
        widget.drawing.asset,
        controller: _controller,
        onLoaded: _loaded,
        height: widget.height,
        width: widget.height * widget.drawing.aspectRatio,
        delegates: LottieDelegates(
          values: [
            ValueDelegate.strokeColor(const ['**'], value: colors.ink),
            ValueDelegate.color(const ['**'], value: colors.accent),
          ],
        ),
      ),
    );
  }
}
