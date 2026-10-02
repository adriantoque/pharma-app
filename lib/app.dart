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
      // Pinned to light rather than left following the system. The light theme
      // was chosen for the product, and darkTheme is kept so the dark palette
      // stays exercised by the tests.
      themeMode: ThemeMode.light,
      // The router is owned and disposed by its Provider.
      routerConfig: context.read<GoRouter>(),
    );
  }
}
