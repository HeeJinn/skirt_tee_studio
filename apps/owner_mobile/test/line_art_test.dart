import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:owner_mobile/presentation/widgets/ui/line_art.dart';

Future<Animation<double>> _pumpLineArt(WidgetTester tester, {required bool reduceMotion}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(child: LineArt(LineArtDrawing.tee, height: 96)),
      ),
    ),
  );
  // Let the drawing's file load.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  return tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller!;
}

void main() {
  testWidgets('draws itself once, then stays drawn', (tester) async {
    final progress = await _pumpLineArt(tester, reduceMotion: false);
    expect(progress.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(progress.value, 1);
  });

  testWidgets('appears already drawn with Reduce Motion on', (tester) async {
    final progress = await _pumpLineArt(tester, reduceMotion: true);
    expect(progress.value, 1);
  });

  testWidgets('every drawing has a file', (tester) async {
    for (final drawing in LineArtDrawing.values) {
      final data = await tester.runAsync(() => DefaultAssetBundle.of(tester.binding.rootElement!).load(drawing.asset));
      expect(data!.lengthInBytes, greaterThan(0), reason: drawing.asset);
    }
  });
}
