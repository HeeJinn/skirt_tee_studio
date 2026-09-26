import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:shop_core/core/theme/app_theme.dart';
import 'package:skirt_tee_studio/presentation/widgets/success_check.dart';

void main() {
  test('hand-authored success.json parses as a 1s, two-layer Lottie', () async {
    final composition = await LottieComposition.fromBytes(File('assets/lottie/success.json').readAsBytesSync());

    expect(composition.duration, const Duration(seconds: 1));
    expect(composition.layers, hasLength(2));
  });

  testWidgets('plays once and settles; static icon under reduced motion', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SuccessCheck())));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); // asset load
    await tester.pumpAndSettle();
    expect(find.byType(LottieBuilder), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const MediaQuery(data: MediaQueryData(disableAnimations: true), child: Scaffold(body: SuccessCheck())),
    ));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
