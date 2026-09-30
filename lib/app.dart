import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PharmaGuide',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      // Pinned to light, not left following the system. bgtheme.png is an 88%
      // luminance image, so the dark theme's near-white text would sit on
      // cream and be unreadable. darkTheme is kept so the dark palette stays
      // exercised by the tests if the artwork is ever replaced.
      themeMode: ThemeMode.light,
      // No `builder` background here on purpose: the artwork is mounted by
      // AppShell instead, so it covers the signed-in area only and the login
      // route keeps a plain surface. The transparent scaffold backgrounds in
      // the theme are what let it show through from there.
      // The router is owned and disposed by its Provider.
      routerConfig: context.read<GoRouter>(),
    );
  }
}
