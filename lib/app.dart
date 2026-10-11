import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppThemeController _themeController = AppThemeController();

  @override
  void initState() {
    super.initState();
    unawaited(_themeController.load());
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppThemeController>.value(
      value: _themeController,
      child: Consumer<AppThemeController>(
        builder: (context, controller, _) => MaterialApp.router(
          title: 'PharmaGuide',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: controller.themeMode,
          // The chosen text scale multiplies the platform's own, so a user who
          // has already enlarged text system-wide keeps that and the in-app
          // slider adds to it rather than replacing it.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  media.textScaler.scale(1.0) * controller.textScale,
                ),
              ),
              child: child!,
            );
          },
          // The router is owned and disposed by its Provider.
          routerConfig: context.read<GoRouter>(),
        ),
      ),
    );
  }
}
