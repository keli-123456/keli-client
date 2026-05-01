import 'package:flutter/material.dart';

import 'services/core_manager.dart';
import 'services/keli_api.dart';
import 'services/session_store.dart';
import 'state/app_controller.dart';
import 'theme.dart';
import 'ui/app_shell.dart';

class KeliClientApp extends StatefulWidget {
  const KeliClientApp({super.key});

  @override
  State<KeliClientApp> createState() => _KeliClientAppState();
}

class _KeliClientAppState extends State<KeliClientApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(
      api: RealKeliApi(),
      coreManager: createCoreManager(),
      sessionStore: SessionStore(),
    )..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppControllerScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Keli Client',
        theme: buildKeliTheme(),
        home: const AppShell(),
      ),
    );
  }
}
