import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keli_client/src/services/core_manager.dart';
import 'package:keli_client/src/services/keli_api.dart';
import 'package:keli_client/src/services/session_store.dart';
import 'package:keli_client/src/state/app_controller.dart';
import 'package:keli_client/src/theme.dart';
import 'package:keli_client/src/ui/app_shell.dart';

void main() {
  testWidgets('Keli Client renders shell', (WidgetTester tester) async {
    final temp = await Directory.systemTemp.createTemp('keli-client-test-');
    final controller = AppController(
      api: MockKeliApi(),
      coreManager: MockCoreManager(),
      sessionStore: SessionStore(root: temp),
    )..isBootstrapping = false;

    await tester.pumpWidget(
      AppControllerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildKeliTheme(),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('登录'), findsWidgets);
    expect(find.text('面板地址'), findsOneWidget);

    controller.dispose();
    await temp.delete(recursive: true);
  });
}
