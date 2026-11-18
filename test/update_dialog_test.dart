import 'package:cloudreve_view/models/app_release.dart';
import 'package:cloudreve_view/widgets/update/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final release = AppRelease(
    tag: '1.0.0-beta.3',
    version: AppVersion.tryParse('1.0.0-beta.3')!,
    title: 'Beta 3',
    notes: '新增：检查更新',
    pageUrl: 'https://example.com/releases/tag/1.0.0-beta.3',
    downloadUrl:
        'https://example.com/releases/download/1.0.0-beta.3/cloudreve-1.0.0-beta.3.apk',
    size: 25913839,
    publishedAt: DateTime(2026, 11, 19, 10),
    isPrerelease: true,
  );

  /// 用一个按钮触发弹窗，把弹窗返回值带回测试里。
  Future<void> pumpTrigger(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onPressed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onPressed(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('更新弹窗展示版本变化与更新说明', (tester) async {
    UpdateDialogAction? action;
    await pumpTrigger(tester, (context) async {
      action = await showUpdateDialog(
        context,
        release: release,
        currentVersion: '1.0.0-beta.2',
      );
    });

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('预发布版本'), findsOneWidget);
    expect(find.text('1.0.0-beta.2'), findsOneWidget);
    expect(find.text('1.0.0-beta.3'), findsOneWidget);
    expect(find.textContaining('检查更新'), findsOneWidget);
    expect(find.textContaining('24.7 MB'), findsOneWidget);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    expect(action, UpdateDialogAction.download);
  });

  testWidgets('没有安装包时改为打开发布页', (tester) async {
    UpdateDialogAction? action;
    final noAsset = AppRelease(
      tag: '1.0.0-beta.4',
      version: AppVersion.tryParse('1.0.0-beta.4')!,
      title: 'Beta 4',
      notes: '',
      pageUrl: 'https://example.com/releases/tag/1.0.0-beta.4',
    );
    await pumpTrigger(tester, (context) async {
      action = await showUpdateDialog(
        context,
        release: noAsset,
        currentVersion: '1.0.0-beta.3',
      );
    });

    expect(find.text('该版本没有提供更新说明。'), findsOneWidget);
    expect(find.text('打开发布页'), findsOneWidget);

    await tester.tap(find.text('打开发布页'));
    await tester.pumpAndSettle();
    expect(action, UpdateDialogAction.openPage);
  });

  testWidgets('安装提示弹窗返回是否安装', (tester) async {
    bool? install;
    await pumpTrigger(tester, (context) async {
      install = await showUpdateReadyDialog(
        context,
        fileName: 'cloudreve-1.0.0-beta.3.apk',
        version: '1.0.0-beta.3',
      );
    });

    expect(find.text('新版本已下载'), findsOneWidget);
    expect(find.textContaining('cloudreve-1.0.0-beta.3.apk'), findsOneWidget);

    await tester.tap(find.text('立即安装'));
    await tester.pumpAndSettle();
    expect(install, isTrue);
  });
}
