import 'package:cloudreve_view/widgets/popup/app_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appPopupWidth', () {
    test('窄屏 75%、宽屏 40%、超宽屏 30%', () {
      expect(appPopupWidth(400), 300);
      expect(appPopupWidth(800), 320);
      expect(appPopupWidth(1200), 360);
    });

    test('断点：600 起 40%，1000 起 30%', () {
      expect(appPopupWidth(599), closeTo(599 * 0.75, 0.01));
      expect(appPopupWidth(600), closeTo(600 * 0.40, 0.01));
      expect(appPopupWidth(999), closeTo(999 * 0.40, 0.01));
      expect(appPopupWidth(1000), closeTo(1000 * 0.30, 0.01));
    });
  });

  group('AppPopup 宽度', () {
    Future<void> pumpPopup(
      WidgetTester tester,
      double screenWidth,
      Widget child, {
      double? customWidth,
    }) async {
      tester.view.physicalSize = Size(screenWidth, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppPopup(width: customWidth, child: child),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('所有悬浮窗都按屏幕档位取宽', (tester) async {
      for (final entry in <double, double>{
        400: 300,
        800: 320,
        1200: 360,
      }.entries) {
        await pumpPopup(
          tester,
          entry.key,
          const SizedBox(width: 100, height: 40),
        );
        expect(
          tester.getSize(find.byType(AppPopup)).width,
          closeTo(entry.value, 0.01),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('内容过宽时仍按档位宽度，不会超出屏幕', (tester) async {
      await pumpPopup(tester, 800, const SizedBox(width: 2000, height: 40));
      final width = tester.getSize(find.byType(AppPopup)).width;
      expect(width, closeTo(320, 0.01));
      expect(width, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('支持自定义宽度，但仍不超过屏幕', (tester) async {
      await pumpPopup(
        tester,
        800,
        const SizedBox(width: 100, height: 40),
        customWidth: 240,
      );
      expect(
        tester.getSize(find.byType(AppPopup)).width,
        closeTo(240, 0.01),
      );

      await pumpPopup(
        tester,
        800,
        const SizedBox(width: 100, height: 40),
        customWidth: 2000,
      );
      expect(
        tester.getSize(find.byType(AppPopup)).width,
        lessThanOrEqualTo(800),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
